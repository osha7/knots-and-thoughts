# Observability, Error Reporting, and Infrastructure Boundaries

How the Owner finds out when something is wrong, at zero cost, without shipping guest
data to a third party.

---

## 1. Deliberately excluded infrastructure

### Docker — not used

Docker earns its place when you need reproducible local development across several
services, or parity with production. Neither applies here.

Production is Vercel's serverless runtime, which **cannot** be run in a container.
Docker would therefore not provide production parity — it would provide a
*confidently different* environment from production, which is worse than none, because
it invites you to trust local behaviour that does not transfer.

The only backing service is Postgres, and Neon provides free **database branches**:

```bash
neonctl branches create --name feature/calendar-feed
```

That yields a real branch of the production database on the identical engine and
version. Strictly better than a local Docker Postgres, at the same zero cost.

**Contrast, for calibration:** `loop-api` at the author's workplace correctly uses
Docker Compose — it runs Postgres, Redis, BullMQ workers, and an API server, and four
services with startup ordering is exactly the problem Docker solves. One managed
database is not that problem.

**Revisit if:** the project grows a long-running background worker (likely for the
photography print store — order processing, image derivative generation).

### AWS — not used

The free tier is the trap. Most AWS free-tier allowances run for **12 months** and then
bill — RDS especially. Choosing AWS would plant a cost landmine that detonates a year
in, breaking the zero-cost requirement on a delay rather than immediately.

It is also not free on day one: Route 53 charges $0.50/month per hosted zone. And
assembling Lambda + API Gateway + RDS + CloudFront + Route 53 is roughly twenty times
the setup effort of Vercel + Neon, with IAM and VPC configuration as the reward, for a
site that displays one event per week.

**Revisit for the print store, with a caveat:** high-resolution image serving does want
object storage. Prefer **Cloudflare R2** over S3 — R2 charges no egress fees, and image
serving is almost entirely egress. S3 egress on a popular gallery is a well-known source
of surprise bills.

---

## 2. The three legs of knowing something is wrong

Ordered by value, which is not the order people usually build them in.

| Leg | Catches | Cost |
|-----|---------|------|
| **Uptime monitoring** | Site down, database unreachable, bad deploy — failures that throw no error anywhere you'd see | $0 |
| **Error reporting** | Server Action failures, unhandled exceptions, cron failures | $0 |
| **Platform notifications** | Failed deploys, failed CI | $0, already built |

**Leg one matters most and is usually built last.** If Neon has an outage, nothing in
the application throws — the site is simply dead, and the Owner finds out when a friend
texts on Wednesday evening. That is the failure that actually costs something.

---

## 3. Uptime monitoring

### Health endpoint

`app/api/health/route.ts` — must verify *real* database connectivity, not merely that
the process is alive. An endpoint returning 200 because Node is running tells you
nothing useful.

```ts
export async function GET() {
  const startedAt = performance.now();
  try {
    await prisma.$queryRaw`SELECT 1`;
    const upcomingCount = await countUpcomingOccurrences();
    return Response.json(
      {
        status: 'ok',
        db: 'reachable',
        upcomingCount,
        ms: Math.round(performance.now() - startedAt),
      },
      { status: 200, headers: { 'Cache-Control': 'no-store' } },
    );
  } catch {
    // Deliberately no error detail — this endpoint is unauthenticated.
    return Response.json({ status: 'degraded', db: 'unreachable' }, { status: 503 });
  }
}
```

Notes:

- `no-store`, or a CDN will happily serve a cached 200 while the database is down.
- No error detail in the body. The endpoint is public; leaking connection strings or
  internal hostnames in a failure message is a real and common pattern.
- Expect an occasional slow first response — Neon's free tier suspends when idle
  (D-03). Set the monitor timeout to 15s so a cold start is not reported as an outage.

### Monitor

**UptimeRobot** free tier — 50 monitors, 5-minute interval, email and mobile push.
Alternative: **Better Stack** free tier — 10 monitors, 3-minute interval, somewhat
nicer incident handling.

Configuration:

- URL `https://knotsandthoughts.com/api/health`
- Keyword monitor asserting the body contains `"status":"ok"` — not merely HTTP 200, so
  a degraded-but-responding state still alerts
- Interval 5 minutes, timeout 15s
- Alert after 2 consecutive failures, to absorb cold starts

### A monitor for the thing that actually matters on Wednesday

Genuinely useful and easy to overlook: a second keyword monitor that fails when
`upcomingCount` is `0`.

A silent empty schedule is arguably worse than an outage — the site is up and
confidently telling all your friends that nothing is happening. This catches "everyone
forgot to schedule anything" before your friends discover it for you.

---

## 4. Error reporting — self-hosted, and why not Sentry

### The decision

Sentry's free tier (5,000 errors/month) is genuinely good and its Next.js SDK is
excellent. It is nevertheless the wrong choice **here**, for a reason worth stating
precisely.

Sentry captures request URLs. One of this application's URLs is:

```
/api/calendar/8f3ae91c…c21.ics
```

That token **is a bearer credential** — whoever holds it can read the feed. Sending
those URLs to Sentry means subscribers' access tokens are stored in a third party's
database. It is fixable with `beforeSend` URL scrubbing, but it is exactly the class of
thing that breaks quietly during a refactor, and it directly undercuts the privacy
guarantee that D-11 and D-13 went to real effort to make structurally true rather than
merely promised.

We therefore keep error data in our own database. The tradeoff, stated honestly: no
source-map symbolication and no release tracking. Server-side Next.js stack traces are
readable without symbolication, so the practical loss is confined to client-side errors.

### Schema addition

```prisma
/// Self-hosted error aggregation. See OBSERVABILITY.md §4.
/// Deduplicated by fingerprint so a hot loop produces one row, not thousands.
model ErrorReport {
  id          String    @id @default(cuid())
  fingerprint String    @unique          // SHA-256 of (normalized message + top app frame)
  message     String
  stack       String?
  route       String?                    // SCRUBBED of tokens and query strings
  level       String    @default("error")
  context     Json?                      // redacted key/value detail
  count       Int       @default(1)
  firstSeenAt DateTime  @default(now())
  lastSeenAt  DateTime  @default(now())
  notifiedAt  DateTime?                  // null = awaiting the next digest
  resolvedAt  DateTime?

  @@index([lastSeenAt])
  @@index([notifiedAt, resolvedAt])
}
```

### Capture

`src/lib/errors.ts`:

```ts
const SCRUB_PATTERNS: Array<[RegExp, string]> = [
  [/\/api\/calendar\/[^/?#]+/g, '/api/calendar/[token]'],
  [/\/auth\/callback\/[^/?#]+/g, '/auth/callback/[token]'],
  [/([?&](token|code|secret|passphrase)=)[^&]*/gi, '$1[redacted]'],
];

const DENY_KEYS = new Set([
  'passphrase', 'password', 'token', 'secret', 'authorization',
  'cookie', 'streetAddress', 'email', 'ip',
]);
```

`reportError(error, { route, context })` does four things:

1. **Scrub** `route` through `SCRUB_PATTERNS` and drop the query string entirely.
2. **Redact** `context` recursively, stripping any key in `DENY_KEYS`.
3. **Fingerprint** as `sha256(normalizedMessage + firstAppStackFrame)`. Normalising
   strips cuids, UUIDs, and bare numbers from the message, so
   `Occurrence abc123 not found` and `Occurrence def456 not found` group together
   instead of filling the table with near-duplicates.
4. **Upsert.** On conflict, increment `count` and update `lastSeenAt`. Clear
   `notifiedAt` **only if the error was previously resolved** — so a regression
   re-alerts, while an ongoing known issue does not re-alert every 15 minutes.

Reporting must never throw. A failure inside the error reporter must not become the
error you are chasing:

```ts
export async function reportError(err: unknown, meta?: ErrorMeta): Promise<void> {
  try {
    // … scrub, fingerprint, upsert
  } catch {
    // Swallowed deliberately. Reporting failure must never mask or replace
    // the original error, and must never break a user-facing request.
  }
}
```

### Notification

Two Vercel Cron jobs, in `vercel.json`:

```json
{
  "crons": [
    { "path": "/api/cron/error-digest",   "schedule": "*/15 * * * *" },
    { "path": "/api/cron/prune-attempts", "schedule": "0 4 * * *" }
  ]
}
```

`/api/cron/error-digest`:

1. **Verify** the `Authorization: Bearer ${CRON_SECRET}` header. Vercel Cron endpoints
   are ordinary public URLs — without this check, anyone who guesses the path can
   trigger them.
2. Select rows where `notifiedAt IS NULL AND resolvedAt IS NULL`.
3. If none, exit quietly.
4. Send **one** email via Resend — subject `[K&T] 3 new errors`, body listing message,
   count, scrubbed route, first-seen time, and a link to `/admin/errors`.
5. Stamp `notifiedAt` on every row included in that digest.

The digest shape is what prevents email storms. A loop throwing 4,000 times produces
one row with `count: 4000` and exactly one email.

`/api/cron/prune-attempts` deletes `AuthAttempt` rows older than 24 hours — data
minimisation, per ARCHITECTURE §8.

### Console

`/admin/errors`, Owner only via a new `errors.view` capability. Lists unresolved reports
by `lastSeenAt`, shows the scrubbed detail, and offers "mark resolved."

A resolved error that recurs re-alerts. That is the behaviour you want: it tells you the
fix did not hold.

### Client-side errors

A React error boundary at the root of the admin console catches render failures and
POSTs a report to `/api/errors/client`.

That endpoint must be treated as hostile input: rate-limited per hashed IP (reusing the
ARCHITECTURE §8 mechanism) and accepting only a fixed, Zod-validated shape. Accepting
arbitrary JSON would hand the world a free write endpoint into your database.

Guest-facing pages need no client boundary — they require no JavaScript to function
(NFR-3), so there is very little client-side surface able to fail.

---

## 5. Platform notifications — free, no code

Enable both. Together they cover every build-time failure for zero effort.

- **Vercel** → Project Settings → Notifications → email on failed deployment
- **GitHub** → Settings → Notifications → email on failed Actions workflow

These catch the single most common real failure: a deploy that does not build. Neither
needs a line of code.

---

## 6. Logging

`src/lib/logger.ts` — a thin structured wrapper writing JSON to stdout, which Vercel
collects automatically.

Redaction is enforced **at the logger**, not left to call sites. A denylist everyone has
to remember to apply is a denylist that eventually is not applied.

**Never logged:** passphrases (plain or hashed), calendar tokens, magic link tokens,
session cookies, street addresses, raw IP addresses, organizer email addresses.

Vercel's Hobby tier retains runtime logs only briefly, which is acceptable — the
`ErrorReport` table is the durable record. If longer retention is ever wanted,
**Axiom**'s free tier (500 GB/month ingest, 30-day retention) has an official Vercel
integration. Not needed at launch.

---

## 7. What this costs

| Component | Cost |
|-----------|------|
| Health endpoint | $0 — application code |
| UptimeRobot or Better Stack | $0 — free tier |
| `ErrorReport` table | $0 — existing Neon database |
| Digest emails via Resend | $0 — well inside 3,000/month |
| Vercel Cron | $0 — Hobby tier includes cron |
| Vercel and GitHub notifications | $0 — built in |

No new vendors beyond one uptime monitor, which receives a single unauthenticated health
URL and no user data whatsoever.

---

## 8. Backup and recovery

A real gap in the original plan. Neon's free tier gives limited point-in-time restore —
enough for "I broke it ten minutes ago," **not** enough for "I deleted every venue last
Tuesday and only noticed now." And the admin console has no undo.

Two cheap layers close it.

### Layer one — soft delete

Do not issue `DELETE` for anything a person can remove through the UI. Add `deletedAt` and
filter it out on read.

```prisma
model Venue {
  // …
  deletedAt DateTime?   // soft delete — recovery without a restore
  @@index([deletedAt])
}
```

Applies to `Venue`, `Organizer` (already has `deactivatedAt`), and `Occurrence`. Not to
`AuthAttempt` or `ErrorReport`, which are genuinely disposable.

The gain: "I deleted the wrong venue" becomes a one-field database fix rather than a
restore. The cost is remembering the filter on every read — so put it in the repository
layer, once, rather than at call sites.

- [ ] `FR-68` Venues, organizers, and occurrences are soft-deleted, never hard-deleted
- [ ] `FR-69` Repository reads exclude soft-deleted rows by default

### Layer two — weekly logical backup

A GitHub Action taking a `pg_dump` and storing it as an encrypted artifact.

```yaml
name: Backup
on:
  schedule: [{ cron: '0 5 * * 0' }]   # Sundays, 05:00 UTC
  workflow_dispatch:                   # so you can test it

jobs:
  dump:
    runs-on: ubuntu-latest
    steps:
      - run: sudo apt-get update && sudo apt-get install -y postgresql-client age
      - run: pg_dump "$DATABASE_URL" --no-owner --no-privileges -Fc -f backup.dump
        env: { DATABASE_URL: "${{ secrets.DATABASE_URL_DIRECT }}" }
      - run: age -r "${{ secrets.BACKUP_AGE_PUBLIC_KEY }}" -o backup.dump.age backup.dump
      - uses: actions/upload-artifact@v4
        with:
          name: backup-${{ github.run_id }}
          path: backup.dump.age
          retention-days: 90
```

Notes that matter:

- **Encrypt before upload.** The dump contains street addresses. GitHub artifacts on a
  public repo are not public, but an unencrypted dump of home addresses sitting in CI
  storage is a poor bet. `age` with an asymmetric key means the workflow can encrypt without
  holding the decryption key.
- Keep the `age` private key in a password manager, **not** in GitHub secrets. A backup you
  can decrypt from the same place that was compromised is not a backup.
- `workflow_dispatch` so you can run it on demand — and so you can prove it works.
- **Restore-test once, in Phase 6.** Restore into a scratch Neon branch and confirm the
  data is intact. An untested backup is a guess. This is the same principle as testing the
  uptime alert by actually breaking the site.

- [ ] `FR-70` A weekly encrypted logical backup runs and is retained 90 days
- [ ] `FR-71` A restore has been performed successfully at least once before launch

### What this does not cover

Stated plainly: this is a weekly snapshot, so worst-case data loss is seven days of
schedule edits. For a weekly event whose details live in one series row and a handful of
overrides, that is an acceptable exposure. It would not be for a store with orders — flag
that for the print store, which needs daily or continuous backup.
