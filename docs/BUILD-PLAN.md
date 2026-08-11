# Build Plan

Phase-by-phase execution, starting from a laptop with nothing installed. Each phase ends
with something deployed and working.

Append to BUILD-LOG.md as you go. The log is what makes the second application faster
than this one.

---

## Phase 0 — Foundations

**Goal:** A deployed, empty, fully tested and monitored application. No features.

Resist the urge to skip ahead. Getting CI, accessibility gates, and the deploy pipeline
working against a trivial application is far easier than retrofitting them onto a real
one, and every later phase inherits the safety.

### 0.1 Accounts

All free. Create with a personal email, not a work one.

- [ ] GitHub — already have `osha7`
- [ ] Vercel — sign in with GitHub
- [ ] Neon — sign in with GitHub
- [ ] Resend — for magic-link email
- [ ] Domain registrar — **Cloudflare Registrar** (at-cost, no markup) or Porkbun
- [ ] UptimeRobot — or Better Stack

### 0.2 Buy the domain

Do this first. DNS propagation and Resend's domain verification both take time, and
neither should be on the critical path later.

- [ ] Register `knotsandthoughts.com`
- [ ] Enable WHOIS privacy — it is free at both registrars and keeps your home address
      out of a public database. *Relevant given this project's whole premise.*
- [ ] Note the renewal date somewhere you will see it

**HTTPS, not HTTP** (D-17). Vercel issues and renews the certificate automatically; there
is nothing to configure and no decision to make.

### 0.3 Local tooling

```bash
# Node via asdf — avoids the permission problems of a system Node, and pins
# the version per-project in a committed .tool-versions
brew install asdf jq
asdf plugin add nodejs && asdf plugin add github-cli
asdf install nodejs 22.23.2 && asdf set nodejs 22.23.2
node --version    # expect v22.x

asdf install github-cli latest && asdf set github-cli latest
gh auth login
```

### 0.4 Repository

```bash
mkdir knots-and-thoughts && cd knots-and-thoughts
npx create-next-app@latest . --typescript --app --tailwind --eslint --src-dir=false
git init
gh repo create knots-and-thoughts --public --source=. --remote=origin
```

**Public from the start** (D-13). Making it public later risks a secret already being in
the history — and history is forever. Starting public forces correct hygiene immediately.

- [ ] Copy this `docs/` directory into the repository
- [ ] `.gitignore` covers `.env*` except `.env.example`
- [ ] `README.md` explains what the project is and links `docs/`

### 0.5 TypeScript strictness

`tsconfig.json` — set these now, before there is code to migrate.

```jsonc
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "exactOptionalPropertyTypes": true,
    "noFallthroughCasesInSwitch": true
  }
}
```

`noUncheckedIndexedAccess` is the one people disable. Keep it. It is what makes the
occurrence-merge code honest about lookups that might miss.

### 0.6 Directory skeleton

Create the ARCHITECTURE §2 layout with placeholder files. Add an ESLint
`no-restricted-imports` rule enforcing the dependency direction:

- [ ] `src/domain/**` may not import from `src/data`, `app`, or `@prisma/client`

That rule is what keeps the domain layer pure and fast to test. Add it before the first
violation, not after the tenth.

### 0.7 Database

- [ ] Create a Neon project, region nearest you
- [ ] Copy both the pooled and direct connection strings
- [ ] `npm i prisma @prisma/client && npx prisma init`
- [ ] Write the full ARCHITECTURE §3 schema, including `ErrorReport` from OBSERVABILITY §4
- [ ] `npx prisma migrate dev --name initial_schema`
- [ ] `npx prisma studio` to confirm

Write the whole schema now even though most tables go unused until later phases. One
considered migration beats six reactive ones, and the schema *is* the privacy guarantee —
seeing it complete makes the absence of guest tables visible.

### 0.8 Environment validation

- [ ] `src/lib/env.ts` — Zod schema over `process.env`, parsed at module load, throws on
      anything missing
- [ ] `.env.example` listing every variable with a comment, no values
- [ ] Generate secrets: `openssl rand -base64 32` for each of `GUEST_SESSION_SECRET`,
      `IP_HASH_SECRET`, `FIELD_ENCRYPTION_KEY`, `AUTH_SECRET`, `CRON_SECRET`

### 0.9 Test harness

- [ ] Install Vitest, React Testing Library, `vitest-axe`, Playwright,
      `@axe-core/playwright`, `@vitest/coverage-v8`
- [ ] `vitest.config.ts` with separate `unit` and `integration` projects
- [ ] `playwright.config.ts` — Chromium, Firefox, WebKit; `webServer` auto-start
- [ ] `tests/support/renderAccessible.tsx` (TEST-PLAN §4)
- [ ] `tests/meta/coverage.test.ts` — fails on any component lacking a test
- [ ] `eslint-plugin-jsx-a11y`, strict preset, warnings as errors
- [ ] Coverage thresholds per TEST-PLAN §9
- [ ] Scripts: `typecheck`, `lint`, `format:check`, `test:unit`, `test:integration`,
      `test:e2e`, `test:a11y`

**Write one trivial component with a test now** and confirm `renderAccessible` fails when
you deliberately remove a label. A gate you have not seen fail is a gate you cannot trust.

### 0.10 CI

- [ ] `.github/workflows/ci.yml` per TEST-PLAN §8, all five jobs
- [ ] GitHub secrets: `NEON_API_KEY`, `NEON_PROJECT_ID`
- [ ] Push a branch, open a pull request, watch all five run
- [ ] Branch protection on `main`: all five required, must be current, no force push
- [ ] **Deliberately break accessibility on a branch** and confirm the `accessibility` job
      fails by name

### 0.11 Deployment

- [ ] Import the repository into Vercel
- [ ] Set every environment variable for Production, Preview, and Development
- [ ] Deploy; confirm the placeholder loads over HTTPS
- [ ] Attach `knotsandthoughts.com` and `www` → apex redirect
- [ ] Confirm HTTP redirects to HTTPS
- [ ] Enable **email on failed deployment** (OBSERVABILITY §5)
- [ ] Enable **email on failed GitHub Actions**

### 0.12 Security headers

- [ ] `next.config.ts` with the ARCHITECTURE §10 header set
- [ ] E2E test asserting each header is present
- [ ] Verify at `securityheaders.com`

### 0.13 Health and monitoring

- [ ] `/api/health` per OBSERVABILITY §3
- [ ] UptimeRobot keyword monitor on `"status":"ok"`, 5-minute interval, 15s timeout,
      alert after 2 failures
- [ ] Stop the Neon branch and confirm you actually get the alert

**Test the alarm.** An untested monitor is decoration.

### Phase 0 exit criteria

- [ ] `https://knotsandthoughts.com` serves a page
- [ ] All five CI jobs green, and required for merge
- [ ] Accessibility gate proven to fail when it should
- [ ] Uptime alert proven to fire
- [ ] No secret in git history
- [ ] BUILD-LOG.md updated

---

## Phase 1 — Guest read path, with privacy upfront

**Goal:** The site becomes genuinely useful. A friend can enter the passphrase and see
this week's details — and can read the privacy policy *before* deciding to.

Privacy and transparency pages ship in this phase, not later. The gate must never exist
without the policy linked from it.

### 1.1 Domain layer first

Pure functions, no UI, no database. Written test-first — the tests in TEST-PLAN §3.1 are
already specified, so this is close to executable.

- [ ] `src/domain/occurrence/candidateDates.ts`
- [ ] `src/domain/occurrence/resolve.ts`
- [ ] `src/domain/occurrence/revealAddress.ts`
- [ ] All TEST-PLAN §3.1 cases, **including every DST case**
- [ ] 100% coverage on `src/domain/`

Do not proceed until the DST tests pass. That bug is invisible for months and then wrong
twice a year.

### 1.2 Crypto and session

- [ ] `src/lib/crypto.ts` — Argon2id, HMAC, token generation
- [ ] `src/lib/datetime.ts` — wall-clock + zone → instant
- [ ] Guest session cookie sign and verify
- [ ] TEST-PLAN §3.4 cases

### 1.3 Data and service layers

- [ ] `passphraseRepo`, `seriesRepo`, `occurrenceRepo`, `venueRepo`, `rateLimitRepo`
- [ ] `guestAuthService` — verify, rate limit, issue session
- [ ] `scheduleService` — resolve upcoming occurrences
- [ ] Integration tests against a Neon branch
- [ ] `prisma/seed.ts` creating a series, two venues, and a few occurrences

### 1.4 Privacy and transparency pages

Build these **before** the gate, so the gate has something to link to.

- [ ] `/privacy` — TRANSPARENCY-PAGES §4 copy
- [ ] `/transparency` — TRANSPARENCY-PAGES §5 copy
- [ ] Native `<details>`/`<summary>`, no JavaScript
- [ ] In-page table of contents
- [ ] "Last updated" derived from git commit date at build time
- [ ] Both override the global `noindex` (FR-52)
- [ ] Middleware **exempts** both from the passphrase check
- [ ] E2E: both reachable with **no** session cookie (FR-46)

GitHub links will 404 until the repository is public — verify them once it is.

### 1.5 Passphrase gate

- [ ] `middleware.ts` — validate session, rewrite to gate on failure, exempt
      `/privacy`, `/transparency`, `/api/health`
- [ ] `PassphraseForm` per ACCESSIBILITY §3 markup
- [ ] Server Action `verifyPassphrase`
- [ ] Rate limiting, generic error text
- [ ] **Paste not blocked; `autocomplete="current-password"` present** (FR-7)
- [ ] Show/hide toggle as a `<button aria-pressed>`
- [ ] Privacy and transparency links **on the gate itself** (FR-47)

### 1.6 Details view

- [ ] `NextEventCard`, `UpcomingList`, `CancelledBadge`, `AccessNotes`, `SkipLink`,
      `Footer`
- [ ] Server Component — at most two queries (NFR-2)
- [ ] `<time datetime>`; timezone named in text
- [ ] Approximate area when `addressVisible` is false
- [ ] Empty state when nothing is scheduled
- [ ] Every component test uses `renderAccessible`

### 1.7 Verify

- [ ] All component tests pass, zero axe violations
- [ ] E2E J1, J2, J3, J3b
- [ ] **E2E with `javaScriptEnabled: false`** — gate submits, details render
- [ ] Accessibility sweep on `/`, `/privacy`, `/transparency`, both themes
- [ ] **Manual keyboard pass**
- [ ] **Manual VoiceOver pass** — macOS and iOS
- [ ] 400% zoom, 320px width
- [ ] Record all manual results in BUILD-LOG.md

### Phase 1 exit criteria

- [ ] A friend can be given the URL and passphrase and it works on their phone
- [ ] They can read the privacy policy without entering anything
- [ ] Works with JavaScript disabled
- [ ] Zero automated accessibility violations
- [ ] Manual passes recorded

**Stop here and use it for a week.** A working site with database-seeded content is more
valuable than a half-built console, and a week of real use will tell you things no plan
predicted. Write those in BUILD-LOG.md.

---

## Phase 2 — Admin authentication

**Goal:** Organizers can sign in. Console shell exists; it does nothing yet.

- [ ] Install Auth.js v5 with the Email provider and Prisma adapter
- [ ] Verify the domain in Resend; add DKIM and SPF DNS records
- [ ] Configure `EMAIL_FROM` as `hello@knotsandthoughts.com`
- [ ] Magic links: single use, 15-minute expiry, **expiry stated in the email**
      (ACCESSIBILITY §2, SC 2.2.1)
- [ ] Unknown email → identical response, nothing sent (FR-29)
- [ ] Rate limit per email and per hashed IP
- [ ] Admin session separate from guest session, 7-day expiry
- [ ] `app/admin/layout.tsx` session guard
- [ ] Seed yourself as the first Owner
- [ ] **Seed a second Owner** — the lockout mitigation from PRD §11 only works if you
      actually do it
- [ ] Integration tests: expiry, single use, enumeration resistance
- [ ] E2E: full sign-in with a mailbox stub
- [ ] Accessibility sweep and manual passes on the sign-in and console shell

---

## Phase 3 — Event editing

**Goal:** Organizers manage the schedule. No role restrictions yet — everyone signed in
can do everything. Roles land in Phase 4.

- [ ] Series defaults form
- [ ] Venue create and edit, with **accessibility notes prominent, not hidden**
      (ACCESSIBILITY §4)
- [ ] Occurrence list with per-field inherited/overridden state
- [ ] `InheritedFieldIndicator` — **the highest-risk component here.** Text or named icon,
      never colour alone (FR-34)
- [ ] "Revert to series default" per overridden field
- [ ] Cancel and un-cancel with a reason
- [ ] `revealAddressAt` control
- [ ] Every mutation writes an `AuditEntry`
- [ ] Every Server Action validates input with Zod before touching the database
- [ ] E2E J6 — changing the series default moves non-overridden weeks and leaves
      overridden ones alone
- [ ] E2E J8 — cancellation visible to guests
- [ ] Accessibility sweep, keyboard pass, VoiceOver pass

**Give the `InheritedFieldIndicator` its own VoiceOver pass.** Close your eyes and have
someone else drive. If you cannot tell inherited from overridden, it has failed regardless
of what axe says.

---

## Phase 4 — Roles and authorization

**Goal:** Four roles, enforced server-side.

- [ ] `src/domain/auth/permissions.ts` — the PRD §6 matrix
- [ ] Table-driven test over all 56 role × capability pairs
- [ ] Row-level Host cases (TEST-PLAN §3.2)
- [ ] Guardrails: last Owner, self-demotion, host reassignment (TEST-PLAN §3.3)
- [ ] **Guard clause in every Server Action** — not the layout, every action (D-18)
- [ ] Organizer invite, role change, and removal — Owner only
- [ ] Read-only occurrence view with a **stated reason**, not a bare disabled control
- [ ] Route-level guards per console section
- [ ] Integration test per Server Action asserting rejection without capability
- [ ] E2E J5 as a Host — own week editable, others visibly not
- [ ] Accessibility sweep **once per role** — a Host's schedule is different markup

**The failure mode to hunt:** a Server Action that authorizes via the layout rather than
independently. Try calling one directly with a Viewer session and confirm it refuses.

---

## Phase 5 — Calendar subscriptions

**Goal:** Guests subscribe anonymously; feeds update automatically.

- [ ] `CalendarToken` repository and service
- [ ] 32-byte token, SHA-256 stored, plaintext shown once
- [ ] **Assert no PII column exists on the model** — a test that reads the Prisma schema
      and fails if `email`, `name`, or `ip` appears on `CalendarToken`. Odd-looking, but it
      is what makes D-11 permanent rather than a current fact.
- [ ] `/api/calendar/[token]/route.ts` with `ical-generator`
- [ ] `DTSTART;TZID=` with local time, never a UTC `Z` value
- [ ] `STATUS:CANCELLED` for cancelled weeks
- [ ] **`LOCATION` carries the venue name only** (FR-23, D-12)
- [ ] E2E asserting no street address appears anywhere in the raw `.ics` body
- [ ] Revoked or unknown token → 404, indistinguishable
- [ ] Owner-only token list and revoke
- [ ] `CalendarSubscribeButton` with a polite live region on copy
- [ ] **Test in Apple Calendar, Google Calendar, and Outlook** by actually subscribing
- [ ] **Update `/privacy` and `/transparency` in this same phase** — tokens are now stored,
      so the pages must say so (TRANSPARENCY-PAGES §7)

---

## Phase 6 — Observability, hardening, launch

- [ ] `ErrorReport` capture with scrubbing (OBSERVABILITY §4)
- [ ] `/api/cron/error-digest` and `/api/cron/prune-attempts` in `vercel.json`
- [ ] `CRON_SECRET` verification on both; E2E asserting rejection without it
- [ ] `/admin/errors`, Owner only
- [ ] Root error boundary → `/api/errors/client`, rate limited, fixed Zod shape
- [ ] Second uptime monitor on `upcomingCount == 0`
- [ ] Trigger a real error and confirm the digest email arrives
- [ ] CSP with no `unsafe-inline` in production
- [ ] Full accessibility audit, all routes, all roles, both themes
- [ ] **NVDA pass on Windows** — different bugs from VoiceOver
- [ ] Forced-colours pass
- [ ] Lighthouse ≥95 accessibility, LCP under 2.0s on simulated 4G
- [ ] Secret rotation procedure written down
- [ ] Owner lockout recovery procedure written down and **rehearsed once**
- [ ] Confirm every free tier still shows $0
- [ ] Set the passphrase to something real; share it with the group

### Launch checklist

- [ ] Domain live over HTTPS, HTTP redirecting
- [ ] Two Owners exist and both have signed in
- [ ] `robots.txt` disallows; gated pages `noindex`; transparency pages indexable
- [ ] Privacy and transparency pages accurate as of launch day
- [ ] Uptime monitors firing correctly
- [ ] Error digest working
- [ ] BUILD-LOG.md complete
- [ ] PROCESS-TEMPLATE.md updated with what actually went wrong

---

## Working rhythm

Per phase, in order:

1. Write the domain logic and its tests first — pure, fast, no scaffolding
2. Then data, then service, then UI
3. Component tests as you build each component, never batched at the end
4. Accessibility sweep before opening the pull request
5. Manual keyboard and VoiceOver pass
6. Record in BUILD-LOG.md
7. Merge only with all five CI jobs green

**One branch per phase**, small pull requests within it. Deploy previews let you test each
on a real phone before merging.

**Never skip the manual passes.** The automated gates catch regressions; they do not catch
a design that is technically conformant and practically unusable. That distinction is the
whole reason accessibility was named a core requirement rather than a checklist.
