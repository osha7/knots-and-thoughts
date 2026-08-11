# Architecture

Technical design. Assumes PRD.md for requirements and DECISIONS.md for why each choice
was made.

---

## 1. Stack

| Layer | Choice |
|-------|--------|
| Language | TypeScript, `strict: true` |
| Framework | Next.js (App Router), React Server Components |
| Mutations | Server Actions |
| Styling | Tailwind CSS + a small set of hand-written accessible primitives |
| Database | PostgreSQL on Neon |
| ORM | Prisma |
| Admin auth | Auth.js (NextAuth v5) — Email provider |
| Transactional email | Resend |
| Password hashing | `@node-rs/argon2` |
| Validation | Zod |
| Dates | `@date-fns/tz` with `date-fns` |
| iCalendar | `ical-generator` |
| Unit tests | Vitest + React Testing Library + `vitest-axe` |
| E2E tests | Playwright + `@axe-core/playwright` |
| CI | GitHub Actions |
| Hosting | Vercel |

**No UI component library.** Material UI and similar bring large bundles and their own
accessibility quirks. For roughly a dozen components, hand-written primitives built on
semantic HTML give better control over the accessibility details that matter here.

---

## 2. Layering

Strict dependency direction — arrows point inward only.

```
  app/                    Routes. Thin. Parse input, call a service, render.
    │
    ▼
  src/services/           Orchestration. Transactions, authorization, audit.
    │           │
    ▼           ▼
  src/data/   src/domain/  Repositories (Prisma)  |  Pure logic. Zero I/O.
    │
    ▼
  src/lib/                Crypto, dates, env validation, logging.
```

**The rule that makes this worth having:** `src/domain/` imports nothing from `src/data/`,
`app/`, or Prisma. It is pure functions over plain data. That is what makes the
interesting logic — occurrence resolution, permission checks, address reveal timing —
exhaustively testable without a database, in milliseconds.

```
knots-and-thoughts/
├── app/
│   ├── (guest)/
│   │   ├── page.tsx                  Passphrase gate or details
│   │   └── actions.ts                verifyPassphrase
│   ├── admin/
│   │   ├── layout.tsx                Session guard
│   │   ├── schedule/
│   │   ├── venues/
│   │   ├── organizers/               Owner only
│   │   └── settings/                 Owner only
│   ├── api/
│   │   ├── calendar/[token]/route.ts .ics feed
│   │   └── auth/[...nextauth]/
│   ├── privacy/page.tsx
│   └── layout.tsx
├── src/
│   ├── domain/
│   │   ├── occurrence/
│   │   │   ├── resolve.ts            THE core algorithm
│   │   │   ├── candidateDates.ts
│   │   │   └── revealAddress.ts
│   │   ├── auth/
│   │   │   └── permissions.ts        Capability matrix
│   │   └── types.ts
│   ├── data/
│   │   ├── prisma.ts
│   │   ├── seriesRepo.ts
│   │   ├── occurrenceRepo.ts
│   │   ├── venueRepo.ts
│   │   ├── organizerRepo.ts
│   │   ├── passphraseRepo.ts
│   │   ├── calendarTokenRepo.ts
│   │   └── rateLimitRepo.ts
│   ├── services/
│   │   ├── scheduleService.ts
│   │   ├── guestAuthService.ts
│   │   ├── calendarService.ts
│   │   ├── organizerService.ts
│   │   └── auditService.ts
│   └── lib/
│       ├── env.ts                    Zod-validated, fails fast at startup
│       ├── crypto.ts                 Argon2, HMAC, token generation
│       ├── datetime.ts               Wall-clock + zone → instant
│       └── logger.ts                 Redacting logger
├── prisma/
│   ├── schema.prisma
│   ├── migrations/
│   └── seed.ts
├── tests/
│   ├── unit/
│   ├── integration/
│   └── e2e/
└── docs/                             These documents, copied in
```

---

## 3. Database schema

```prisma
// ---------- Enums ----------

enum Role         { OWNER  EDITOR  HOST  VIEWER }
enum VenueKind    { PRIVATE_HOME  PUBLIC_VENUE }
enum OccStatus    { SCHEDULED  CANCELLED }

// ---------- People ----------

model Organizer {
  id            String    @id @default(cuid())
  email         String    @unique          // organizer, NOT guest — consented, necessary
  displayName   String
  role          Role
  invitedAt     DateTime  @default(now())
  lastSignInAt  DateTime?
  deactivatedAt DateTime?

  hostedOccurrences Occurrence[] @relation("HostedOccurrences")
  defaultForSeries  Series[]     @relation("SeriesDefaultHost")
  auditEntries      AuditEntry[]

  accounts Account[]                       // Auth.js
  sessions Session[]

  @@index([role])
}

// ---------- The event ----------

model Series {
  id              String   @id @default(cuid())
  title           String                    // "Knots & Thoughts"
  dayOfWeek       Int                       // 0=Sun … 3=Wed
  startTimeLocal  String                    // "19:00" — WALL CLOCK, see D-08
  durationMinutes Int      @default(180)
  timeZone        String                    // IANA: "America/Chicago"
  isActive        Boolean  @default(true)

  defaultVenueId  String?
  defaultVenue    Venue?     @relation(fields: [defaultVenueId], references: [id])
  defaultHostId   String?
  defaultHost     Organizer? @relation("SeriesDefaultHost", fields: [defaultHostId], references: [id])

  occurrences Occurrence[]
}

model Venue {
  id            String    @id @default(cuid())
  name          String                      // "Osha's studio" — safe to display
  kind          VenueKind
  approxArea    String?                     // "Oak Street area" — shown before reveal
  streetAddress String?                     // SENSITIVE — encrypted at rest
  city          String?
  region        String?
  mapUrl        String?
  accessNotes   String?                     // step-free entry, parking, restrooms
  isArchived    Boolean   @default(false)

  series      Series[]
  occurrences Occurrence[]
}

/// A row exists ONLY for a week that differs from the series defaults.
/// null on an override field means "inherit from series".
model Occurrence {
  id       String @id @default(cuid())
  seriesId String
  series   Series @relation(fields: [seriesId], references: [id], onDelete: Cascade)

  /// The LOCAL calendar date. Deliberately a DATE, not a timestamp — the
  /// instant is derived from this plus the resolved time plus the zone.
  date DateTime @db.Date

  status       OccStatus @default(SCHEDULED)
  cancelReason String?

  startTimeLocalOverride  String?           // null = inherit
  durationMinutesOverride Int?              // null = inherit
  venueIdOverride         String?
  venue                   Venue?     @relation(fields: [venueIdOverride], references: [id])
  hostIdOverride          String?
  host                    Organizer? @relation("HostedOccurrences", fields: [hostIdOverride], references: [id])

  notes String?

  /// null = address always visible. Otherwise hide street address until this instant.
  revealAddressAt DateTime?

  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@unique([seriesId, date])                // one override row per date, enforced by DB
  @@index([date])
}

// ---------- Guest access ----------

model GuestPassphrase {
  id        String    @id @default(cuid())
  hash      String                          // Argon2id. Plaintext NEVER stored.
  version   Int       @unique               // increments on rotation → invalidates sessions
  createdAt DateTime  @default(now())
  retiredAt DateTime?

  @@index([retiredAt])
}

/// Zero PII by construction. See D-11. No email, no name, no IP column —
/// and none may be added without a new decision entry.
model CalendarToken {
  id            String    @id @default(cuid())
  tokenHash     String    @unique           // SHA-256. The token itself is never stored.
  label         String?                     // optional, self-chosen, e.g. "my phone"
  createdAt     DateTime  @default(now())
  lastFetchedAt DateTime?
  revokedAt     DateTime?

  @@index([revokedAt])
}

// ---------- Operational ----------

/// Rate limiting. ipHash is HMAC(ip, secret) — not reversible to an address.
/// Rows older than 24h are deleted by a scheduled job.
model AuthAttempt {
  id        String   @id @default(cuid())
  ipHash    String
  kind      String                          // GUEST_PASSPHRASE | ADMIN_MAGIC_LINK
  succeeded Boolean
  createdAt DateTime @default(now())

  @@index([ipHash, kind, createdAt])
  @@index([createdAt])
}

model AuditEntry {
  id         String   @id @default(cuid())
  actorId    String?
  actor      Organizer? @relation(fields: [actorId], references: [id], onDelete: SetNull)
  action     String                         // "occurrence.update", "passphrase.rotate"
  targetType String
  targetId   String?
  before     Json?
  after      Json?
  createdAt  DateTime @default(now())

  @@index([createdAt])
  @@index([actorId])
}
```

**Schema notes worth flagging:**

- `Occurrence.date` is a `DATE`, not a timestamp. The actual instant is *derived* from
  date + resolved wall-clock time + series zone. This is what makes DST work.
- `@@unique([seriesId, date])` makes "one override per week" a database invariant, not
  a hope.
- `AuditEntry.actorId` is `onDelete: SetNull` so removing an organizer does not destroy
  the history of what they did.
- No table anywhere carries a guest identifier. That is the whole privacy guarantee, and
  it is enforced by absence.

---

## 4. The core algorithm — occurrence resolution

This is the piece worth getting exactly right. A pure function, no I/O, in
`src/domain/occurrence/resolve.ts`.

```ts
export interface ResolvedOccurrence {
  date: string;                    // "2026-08-12" local calendar date
  startsAt: Date;                  // derived UTC instant, for iCal and sorting
  startTimeLocal: string;          // "19:00"
  timeZone: string;
  durationMinutes: number;
  status: 'SCHEDULED' | 'CANCELLED';
  cancelReason: string | null;
  venue: Venue | null;
  host: Organizer | null;
  notes: string | null;
  addressVisible: boolean;         // computed from revealAddressAt vs now
  overriddenFields: OverriddenField[];  // drives the admin inherited/overridden UI
}

export function resolveOccurrences(input: {
  series: Series;
  overrides: Occurrence[];
  from: Date;
  count: number;
  now: Date;                       // injected — never call new Date() inside
}): ResolvedOccurrence[]
```

Three steps:

1. **Generate candidate dates.** From `from`, produce the next `count` dates matching
   `series.dayOfWeek`, in `series.timeZone`. Pure date arithmetic on local calendar dates.
2. **Merge overrides.** Index overrides by date. For each candidate, apply any override
   field-by-field where the override value is non-null. Record which fields were
   overridden — the admin UI needs this for FR-33.
3. **Derive instants and visibility.** Combine local date + resolved wall-clock time +
   zone into a UTC instant. Compute `addressVisible` from `revealAddressAt` against `now`.

**`now` is always injected, never read from the ambient clock.** This is the single most
important testability decision in the codebase: it makes DST transitions, reveal
boundaries, and "what is the next event" deterministic to test rather than
time-of-day-dependent.

### The DST case, concretely

US daylight saving ends Sunday 2026-11-01. The Wednesdays either side:

| Date | Local time | UTC offset | UTC instant |
|------|-----------|-----------|-------------|
| 2026-10-28 | 19:00 | CDT, −05:00 | 2026-10-29T00:00Z |
| 2026-11-04 | 19:00 | CST, −06:00 | 2026-11-05T01:00Z |

Same stored `startTimeLocal`. Different UTC instants. Guests see 7:00 PM both weeks,
which is correct. Had we stored a UTC timestamp, one of those weeks would display 6:00 PM
or 8:00 PM. This gets an explicit test.

---

## 5. Authorization

A pure function in `src/domain/auth/permissions.ts`, directly transcribing PRD §6.

```ts
export type Capability =
  | 'console.view'      | 'series.edit'        | 'occurrence.create'
  | 'occurrence.editAny'| 'occurrence.editOwn' | 'occurrence.reassignHost'
  | 'occurrence.cancelAny' | 'occurrence.cancelOwn'
  | 'venue.manage'      | 'passphrase.rotate'  | 'organizer.manage'
  | 'calendarToken.revoke' | 'audit.view';

export function can(
  actor: { id: string; role: Role },
  capability: Capability,
  resource?: { hostId?: string | null },
): boolean;
```

Two-tier check, because Host is row-level:

```ts
// Role grants the capability outright?
if (ROLE_CAPABILITIES[actor.role].has(capability)) return true;

// Or: it's an "own resource" capability and they own this one?
if (OWN_RESOURCE_CAPABILITIES.has(capability)) {
  return resource?.hostId === actor.id;
}
return false;
```

**Enforcement points, in order:**

1. `app/admin/layout.tsx` — is there a valid admin session at all
2. Each route segment — does this role have `console.view` plus the section's capability
3. **Every Server Action, independently** — re-verify session and capability before any
   write. Server Actions are public HTTP endpoints; a hidden button protects nothing.
4. Service layer — final guard before the repository

Step 3 is the one that gets forgotten and the one that matters most. Every Server Action
begins with the same guard clause, and TEST-PLAN §4 asserts this for each of them.

---

## 6. Guest session

No database session table. An HMAC-signed cookie:

```
payload  = { v: passphraseVersion, iat: issuedAtUnix }
cookie   = base64url(payload) + "." + base64url(HMAC-SHA256(payload, GUEST_SESSION_SECRET))
```

Set `httpOnly`, `Secure`, `SameSite=Lax`, `Max-Age=2592000` (30 days).

Validation: verify the HMAC in constant time, check `iat` is within 30 days, and check
`v` equals the current passphrase version. Rotating the passphrase increments the
version, which invalidates every outstanding cookie with no session table to purge.

Middleware performs this check; a failure rewrites to the passphrase gate.

---

## 7. Calendar feed

```
GET /api/calendar/{token}.ics
```

1. Hash the supplied token with SHA-256, look it up by `tokenHash`.
2. Not found or revoked → 404. Never distinguish the two.
3. Update `lastFetchedAt`.
4. Resolve the next 12 occurrences.
5. Emit iCalendar.

```
BEGIN:VEVENT
UID:occ-2026-08-12@knotsandthoughts.com
DTSTAMP:20260727T190000Z
DTSTART;TZID=America/Chicago:20260812T190000
DURATION:PT3H
SUMMARY:Knots & Thoughts
LOCATION:Sam's place                     ← venue NAME only, never the street address
DESCRIPTION:Hosted by Sam. Details: https://knotsandthoughts.com
STATUS:CONFIRMED
END:VEVENT
```

`DTSTART;TZID=` with a local time rather than a UTC `Z` value keeps calendar clients
correct through DST.

Cancelled occurrences are emitted with `STATUS:CANCELLED` rather than omitted — a
subscriber's calendar needs the tombstone to remove the entry.

`Cache-Control: private, max-age=1800`.

**LOCATION carries the venue name only.** See D-12: Google and Outlook fetch feeds
server-side and retain the contents, so a street address in the feed is a street address
published to third-party infrastructure.

---

## 8. Rate limiting

```ts
async function checkRateLimit(
  ipHash: string,
  kind: 'GUEST_PASSPHRASE' | 'ADMIN_MAGIC_LINK',
  now: Date,
): Promise<{ allowed: boolean; retryAfter?: Date }>
```

Count failed attempts for that `ipHash` and `kind` within the window. Guest passphrase:
10 per 15 minutes. Magic link: 5 per 15 minutes per IP, 3 per hour per email address.

`ipHash = HMAC-SHA256(ip, IP_HASH_SECRET)` — the raw address is never written anywhere,
including logs. A daily Vercel Cron job deletes rows older than 24 hours.

---

## 9. Configuration

`src/lib/env.ts` parses `process.env` with Zod at module load and throws on anything
missing or malformed. A misconfigured deployment fails at boot with a precise message
rather than at 9pm on a Wednesday with a confusing one.

| Variable | Purpose |
|----------|---------|
| `DATABASE_URL` | Neon pooled connection string |
| `DIRECT_URL` | Neon direct connection, for migrations |
| `GUEST_SESSION_SECRET` | HMAC key for guest cookies (≥32 bytes) |
| `IP_HASH_SECRET` | HMAC key for IP hashing (≥32 bytes) |
| `FIELD_ENCRYPTION_KEY` | AES-256-GCM key for street addresses |
| `AUTH_SECRET` | Auth.js signing key |
| `AUTH_URL` | Canonical site URL |
| `RESEND_API_KEY` | Magic link delivery |
| `EMAIL_FROM` | e.g. `hello@knotsandthoughts.com` |

No secret is ever committed. The repository is public (D-13), which makes this a hard
requirement rather than good hygiene.

---

## 10. Security headers

Set in `next.config.ts` and verified by an e2e test, because headers are exactly the kind
of thing that silently regresses.

```
Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self';
  img-src 'self' data:; font-src 'self'; connect-src 'self'; frame-ancestors 'none';
  base-uri 'self'; form-action 'self'
Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
X-Content-Type-Options: nosniff
Referrer-Policy: no-referrer
X-Robots-Tag: noindex, nofollow
Permissions-Policy: geolocation=(), camera=(), microphone=()
```

The absence of third-party scripts (D-16) is what allows a CSP with no `unsafe-inline`.
