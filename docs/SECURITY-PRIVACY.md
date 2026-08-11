# Security and Privacy

The privacy posture is a design constraint, not a policy page. This document states
what is true, what is not true, and how each claim is enforced.

---

## 1. The governing principle

> A promise about *behaviour* depends on continued good behaviour.
> A fact about *architecture* can be verified by anyone.

"We will not share your data" is the first kind. "There is no subscriber table in the
database" is the second. Wherever possible this project chooses the second, and makes the
source public (D-13) so the claim is auditable rather than merely asserted.

The practical consequence: **we cannot leak what we never collected.**

---

## 2. What is and is not collected

### About guests — nothing identifying

| Data | Collected? | Notes |
|------|:---:|-------|
| Name | ❌ | No field exists anywhere in the schema |
| Email address | ❌ | Not requested for any guest function, including calendar subscription |
| Phone number | ❌ | No SMS, no field |
| Account or profile | ❌ | There are no guest accounts |
| Cookies | ⚠️ | One: a signed session cookie proving the passphrase was entered. Contains a version number and an issue timestamp. No identifier. |
| IP address | ⚠️ | Never stored. Used transiently, hashed with `HMAC-SHA256(ip, IP_HASH_SECRET)`, for rate limiting only. The hash is not reversible to an address. Rows deleted after 24 hours. |
| Calendar token | ⚠️ | A random token you generate. Only its SHA-256 hash is stored, plus a creation date and an optional label you choose yourself. Nothing links it to a person. |

### About organizers — the minimum required

| Data | Collected? | Why |
|------|:---:|-----|
| Email address | ✅ | Required to send magic links. Consented, necessary, and the person is a site administrator, not a visitor. |
| Display name | ✅ | So other organizers can see who hosts which week. |
| Role | ✅ | Authorization. |
| Last sign-in time | ✅ | Detecting dormant accounts. |
| Audit trail of actions | ✅ | Accountability among co-organizers. |

### About the events

Street addresses are the genuinely sensitive data here, because roughly half of venues
are private homes (see PRD §5, and the mixed-privacy decision). They are:

- Encrypted at rest with AES-256-GCM under `FIELD_ENCRYPTION_KEY`, so a database dump
  does not expose them
- Excluded from calendar feeds entirely (D-12)
- Gated behind `revealAddressAt` when the organizer chooses
- Never written to logs (OBSERVABILITY §6) or error reports (§4 scrubbing)

---

## 3. Threat model

What we defend against, and what we explicitly do not.

| Threat | Defended | How |
|--------|:---:|-----|
| Passer-by discovers the address by visiting the URL | ✅ | Passphrase gate |
| Search engine indexes the address | ✅ | `robots.txt` disallow, `X-Robots-Tag: noindex`, and content behind the gate |
| Passphrase brute-forced | ✅ | Argon2id, 10 attempts per 15 minutes per hashed IP, generic errors |
| Passphrase intercepted on shared wifi | ✅ | HTTPS-only, HSTS |
| Database dump exposes home addresses | ✅ | Field-level AES-256-GCM encryption |
| Compromised guest cookie reused indefinitely | ✅ | 30-day expiry; rotation invalidates all sessions immediately |
| Leaked calendar feed URL | ✅ | Individually revocable without affecting others |
| Host escalates to editing others' weeks | ✅ | Row-level authorization, re-verified in every Server Action |
| Host reassigns a week to themselves | ✅ | `occurrence.reassignHost` denied to Host |
| Everyone locked out permanently | ✅ | Last Owner cannot be removed or demoted |
| Enumeration of who is an organizer | ✅ | Unknown-email sign-in returns an identical response and sends nothing |
| Cron endpoints triggered by strangers | ✅ | `CRON_SECRET` bearer check |
| Secrets committed to a public repo | ✅ | All config via env vars, Zod-validated at boot; pre-commit secret scan |
| **A friend forwards the passphrase** | ❌ | **Not defended. See §4.1.** |
| **Determined attacker who already has the passphrase** | ❌ | They are, by design, an authorized guest. |
| Nation-state, physical coercion, malicious insider organizer | ❌ | Out of scope for a friends' event site. |

---

## 4. Four things that are *not* true, stated plainly

These belong in the privacy page in plain language, not buried. Telling your friends
something reassuring but false is worse than telling them the truth.

### 4.1 The shared passphrase is obscurity, not security

Anyone holding the passphrase can forward it to anyone else, and we will never know.
There is no mechanism to detect or trace this. The passphrase raises the cost of casual
discovery; it does not control who ultimately gains access.

*Mitigations available:* rotate it from the console at any time; use `revealAddressAt` so
a private address only appears close to the date; a per-occurrence choice to show only the
approximate area.

### 4.2 Google and Microsoft see calendar feed contents

`.ics` subscriptions work by a calendar client polling a URL. **Google Calendar and
Outlook.com fetch from their own servers, not from the subscriber's device.** Anything in
the feed is retrieved and retained by that provider.

This is unavoidable — it is how those products work. It is why street addresses never
appear in feeds (D-12). Apple Calendar and most desktop clients fetch from the device
directly; a privacy-conscious friend should prefer those.

### 4.3 Vercel and Neon process the data

Two vendors run the application and store the database. Both hold SOC 2 Type II
attestations, and sensitive fields are encrypted at rest so a database dump does not
expose addresses. But "nobody sees this except us" would be false, and we will not say it.

### 4.4 Platform access logs contain IP addresses

Our own tables never store an IP address. Vercel's platform-level access logs do, briefly,
as with any host. We add no analytics, no trackers, and no third-party scripts (D-16), so
this is the only such record and we do not control it.

---

## 5. Privacy page — draft copy

Lives at `/privacy`, linked from the passphrase gate and the details page. Plain language
deliberately; the goal is that a friend actually reads it.

> ## What this site knows about you
>
> **Short version: nothing.** No account, no name, no email, no tracking.
>
> ### What we store
> - A cookie proving you typed the passphrase. It holds a number and a date — not who
>   you are.
> - If you add the calendar subscription: a random code, stored scrambled so even we
>   cannot read the original. Nothing connects it to you.
>
> ### What we never store
> Your name. Your email. Your phone number. Your IP address. Anything about which pages
> you looked at, or when.
>
> There are no analytics, no advertising, and no third-party scripts on this site.
>
> ### Things you should know
> - **The passphrase can be forwarded.** Anyone who has it can pass it to anyone else,
>   and we would not know. Please don't share it outside the group.
> - **If you subscribe with Google Calendar or Outlook, those companies see the event
>   listing** — because their servers, not your phone, fetch the calendar. The listing
>   only ever contains a place *name*, never a street address. Apple Calendar fetches
>   from your device instead.
> - **Home addresses are shown only on this page**, never in the calendar, and sometimes
>   only in the few days before the gathering.
>
> ### Check for yourself
> The code that runs this site is public: [github.com/osha7/knots-and-thoughts](https://github.com/osha7/knots-and-thoughts).
> You do not have to take our word for any of this.

That last section is the point of D-13. It converts the entire page from a promise into
a claim someone can test.

---

## 6. Cryptography

| Purpose | Algorithm | Notes |
|---------|-----------|-------|
| Guest passphrase | Argon2id | `memoryCost` 19456 KiB, `timeCost` 2, `parallelism` 1 (OWASP baseline). Verified in constant time. |
| Guest session cookie | HMAC-SHA256 | Signed, not encrypted — the payload is not secret. Compared with `timingSafeEqual`. |
| Calendar tokens | 32 bytes from `crypto.randomBytes` | base64url encoded (256 bits). Stored as SHA-256 — a fast hash is correct here because the input is already high-entropy; Argon2 would only slow every feed fetch for no gain. |
| IP hashing | HMAC-SHA256 with a server secret | Keyed, so the small IPv4 space cannot be brute-forced back as it could with a bare hash. |
| Street addresses | AES-256-GCM | Authenticated encryption; random 96-bit IV per record. |
| Magic links | Auth.js default | Single-use, 15-minute expiry. |

**On why calendar tokens use SHA-256 and passphrases use Argon2id:** password hashing is
slow deliberately, to defend low-entropy human-chosen secrets against offline guessing.
A 256-bit random token has nothing to guess. Using Argon2 there would add real latency to
every calendar poll and buy nothing.

---

## 7. Secrets management

The repository is public, which turns secret hygiene from good practice into a hard
requirement.

- No secret ever committed. `.env*` gitignored except `.env.example`.
- `src/lib/env.ts` validates every variable with Zod at module load and throws a precise
  message on anything missing or malformed — a misconfigured deploy fails at boot, not at
  9pm on a Wednesday.
- Secrets live in Vercel's encrypted environment variables, set per environment.
- Every HMAC and encryption key is ≥32 bytes from `openssl rand -base64 32`.
- `gitleaks` runs as a pre-commit hook and in CI.
- Rotation procedure documented in BUILD-PLAN Phase 6.

---

## 8. Incident response

Short and concrete, because the moment you need it is the moment you will not want to
improvise.

**Passphrase believed leaked** → Console → Settings → rotate. Every guest session dies
immediately. Notify the group through your usual chat.

**A calendar feed URL leaked** → Console → Calendar feeds → revoke that token. No other
subscriber is affected.

**An organizer's email account compromised** → Owner removes or deactivates them
immediately; the audit log shows what they did while compromised.

**Sole Owner locked out** → Documented recovery: connect to Neon directly and update the
`Organizer` row. This is precisely why two Owners are recommended.

**Database exposure suspected** → Rotate `FIELD_ENCRYPTION_KEY` and re-encrypt addresses;
rotate the guest passphrase; rotate `AUTH_SECRET` to invalidate admin sessions; review
the audit log.

**A wrong address published** → Correct it in the console. Note the propagation delay:
calendar subscribers may hold stale data for up to 30 minutes (the feed's
`Cache-Control`), and addresses are not in feeds anyway.
