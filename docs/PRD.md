# Product Requirements Document — Knots & Thoughts

**Version:** 1.0
**Date:** 2026-07-27
**Owner:** Osha G.
**Status:** Approved for implementation

---

## 1. Summary

A single-page, passphrase-gated website that answers one question reliably: *where
is the Wednesday gathering this week?* Behind it sits an authenticated admin console
where a small group of organizers manage the schedule.

Accessibility and privacy are treated as primary design constraints that shape the
architecture, not as a compliance pass applied at the end.

---

## 2. Problem

The weekly gathering's details change — a different host, a different venue,
occasional cancellations. Today that information lives in group chat, where it
scrolls away. People who miss the message don't know where to go, and the organizer
answers the same question five times by text.

The fix is a single durable URL that is always correct, requires no app and no
account, and works on a phone in a hurry.

---

## 3. Goals

| ID | Goal | How we know it's met |
|----|------|----------------------|
| G1 | A friend learns this week's details in under 10 seconds on a phone, with no account | Manual timing on a real device over cellular; e2e test asserts details are in the initial server-rendered HTML |
| G2 | An organizer updates details in under 60 seconds | Timed e2e test from console sign-in to saved change |
| G3 | Fully usable by keyboard alone and by screen reader, to WCAG 2.2 Level AA | Automated axe checks on every page, plus manual VoiceOver and NVDA passes recorded in BUILD-LOG |
| G4 | Zero personally identifying information is collected about guests, and that is verifiable | No PII columns exist in the schema; repository is public; privacy page states it plainly |
| G5 | Total running cost stays at the price of the domain | Monthly check that no service has exceeded a free tier |
| G6 | The build process is documented well enough to repeat for a different application | The photography print store reuses PROCESS-TEMPLATE.md without needing to re-derive decisions |

---

## 4. Non-goals for v1

Deliberately excluded. Some are permanent, some deferred — the distinction matters.

**Permanently out of scope**

- Per-guest accounts or individual guest identity
- Any collection of guest names, emails, or phone numbers
- SMS or text notifications — the only piece that cannot be free (≈$1.15/month per
  Twilio number plus ≈$0.008/message), and the email-to-SMS gateway workarounds are
  carrier-dependent and largely defunct
- Payments, ticketing, photo galleries, comments, chat
- Native mobile applications
- Full RFC 5545 recurrence rules (`RRULE`, `EXDATE`, and friends)

**Deferred, expected later**

- RSVPs and headcounts
- Change-notification emails to an opted-in list — requires collecting email
  addresses, which conflicts with G4 as currently stated and needs a deliberate
  decision, not a drive-by addition
- Multiple concurrent event series
- More than one locale or timezone

---

## 5. Users

| User | Count | Needs |
|------|-------|-------|
| **Guest** | ~10–40 | Know when and where, fast, on a phone. No signup. Optionally subscribe a calendar. |
| **Owner** | 1–2 | Full control: manage organizers, rotate the passphrase, edit anything, revoke calendar feeds. |
| **Editor** | 1–4 | Manage the schedule freely — any week, any field — without administrative power over people. |
| **Host** | 1–8 | Update only the specific weeks they are hosting. Cannot affect anyone else's week. |
| **Viewer** | 0–4 | Read-only console access for someone who needs the full schedule but must not change it. |

A person holds exactly one role. Roles are hierarchical in practice but implemented
as an explicit capability matrix rather than inherited levels, because "Host can
edit *only their own* week" is not expressible as a level.

---

## 6. Roles and permissions

The authoritative matrix. Every row becomes a test case (see TEST-PLAN.md §4).

| Capability | Owner | Editor | Host | Viewer |
|---|:-:|:-:|:-:|:-:|
| Sign in to console | ✅ | ✅ | ✅ | ✅ |
| View schedule including hidden addresses | ✅ | ✅ | ✅ | ✅ |
| Edit series defaults (day, time, default venue/host, timezone) | ✅ | ✅ | ❌ | ❌ |
| Create an occurrence override for any week | ✅ | ✅ | ❌ | ❌ |
| Edit any occurrence | ✅ | ✅ | ❌ | ❌ |
| Edit an occurrence where they are the assigned host | ✅ | ✅ | ✅ | ❌ |
| Reassign the host of an occurrence | ✅ | ✅ | ❌ | ❌ |
| Cancel any occurrence | ✅ | ✅ | ❌ | ❌ |
| Cancel an occurrence they are hosting | ✅ | ✅ | ✅ | ❌ |
| Manage venues | ✅ | ✅ | ❌ | ❌ |
| Rotate the guest passphrase | ✅ | ❌ | ❌ | ❌ |
| Invite, remove, or change the role of an organizer | ✅ | ❌ | ❌ | ❌ |
| Revoke calendar feed tokens | ✅ | ❌ | ❌ | ❌ |
| View the audit log | ✅ | ✅ | ❌ | ❌ |

**Deliberate constraints:**

- A Host cannot reassign the host field. Otherwise a Host could hand their week to
  someone else, or take a week that isn't theirs — a privilege-escalation path.
- The last remaining Owner cannot be demoted or removed. Prevents locking everyone
  out of the site permanently.
- An Owner cannot change their own role. Same reasoning, narrower case.

---

## 7. Primary user journeys

**J1 — First visit as a guest.** Lands on `knotsandthoughts.com`. Sees the group
name, a short explanation, and one passphrase field. Enters the passphrase, is taken
to the details page. A cookie remembers them for 30 days.

**J2 — Returning guest.** Lands on the site, cookie is valid, sees details
immediately with no interstitial.

**J3 — Wrong passphrase.** Clear error text, programmatically associated with the
field and announced to screen readers. Generic wording — never "that passphrase was
close." After 10 failed attempts from one network in 15 minutes, further attempts
are throttled with an explanation of when they may retry.

**J4 — Guest subscribes a calendar.** From the details page, activates "Add to your
calendar." Receives a unique feed URL and platform-specific instructions. No email,
no name, no form. Their calendar updates automatically when organizers change
anything.

**J5 — Host updates their week.** Signs in with a magic link. Sees the schedule with
their own hosted week editable and every other week read-only, with a visible reason
why. Changes the time, saves, sees confirmation.

**J6 — Owner changes the standing time permanently.** Edits the series default from
7:00pm to 6:30pm. Every week that has not been individually overridden now reads
6:30pm. Weeks with an explicit time override keep it, and the console shows which
those are.

**J7 — Owner rotates the passphrase.** Sets a new one. All existing guest sessions
become invalid and everyone re-enters on next visit. Existing calendar feeds are
unaffected — separate credential, separate lifecycle.

**J8 — Organizer cancels a week.** Marks it cancelled with a short reason. Guests
see a clear "no gathering this week" state rather than an empty page. Calendar
subscribers see the event marked cancelled.

---

## 8. Functional requirements

Numbered for direct traceability to tests. Each is independently verifiable.

### Guest access

- **FR-1** The root URL presents a passphrase form to visitors without a valid session.
- **FR-2** The passphrase is verified against an Argon2id hash. The plaintext is never
  stored, never logged, and never placed in an environment variable.
- **FR-3** A correct passphrase issues an HMAC-signed, `httpOnly`, `Secure`,
  `SameSite=Lax` cookie valid for 30 days.
- **FR-4** The cookie embeds the passphrase version. Rotating the passphrase increments
  the version and invalidates every existing session.
- **FR-5** An incorrect passphrase shows a generic error and reveals nothing about how
  close the attempt was.
- **FR-6** Failed attempts are rate-limited per hashed client IP: 10 attempts per 15
  minutes, then a lockout with a stated retry time.
- **FR-7** The passphrase field permits paste and password-manager autofill.
  *(Blocking paste is a WCAG 2.2 SC 3.3.8 failure.)*
- **FR-8** All pages are served over HTTPS. HTTP requests are permanently redirected.
- **FR-9** `robots.txt` disallows all crawlers and every page sends
  `X-Robots-Tag: noindex, nofollow`.

### Guest details view

- **FR-10** The next upcoming occurrence is displayed most prominently.
- **FR-11** The following two occurrences are also shown, in a clearly secondary position.
- **FR-12** Each occurrence shows date, start time with timezone, venue name, host name,
  and any notes.
- **FR-13** Times display in the series timezone with the zone named explicitly
  (e.g. "7:00 PM Central"). Times are never silently converted to the viewer's zone.
- **FR-14** An occurrence whose venue has a `revealAddressAt` in the future shows the
  approximate area instead of the street address.
- **FR-15** A cancelled occurrence displays an unambiguous cancelled state with its reason.
- **FR-16** When no upcoming occurrence exists, an explanatory empty state appears —
  never a blank region.
- **FR-17** Venue accessibility notes (step-free entry, parking, restroom access) display
  when present.
- **FR-18** The full details view is present in server-rendered HTML and readable with
  JavaScript disabled.

### Calendar subscription

- **FR-19** Guests can generate a calendar feed URL containing a cryptographically random
  token of at least 128 bits of entropy.
- **FR-20** Only a SHA-256 hash of the token is stored. The token itself is shown once and
  never persisted.
- **FR-21** No email address, name, IP address, or any other identifying field is stored
  against a feed token.
- **FR-22** The feed URL returns valid iCalendar (RFC 5545) content that Apple Calendar,
  Google Calendar, and Outlook all accept.
- **FR-23** The feed contains venue *name* only. Street addresses never appear in the feed.
  *(See SECURITY-PRIVACY.md §4 — third-party calendar servers fetch and retain feed contents.)*
- **FR-24** Cancelled occurrences are emitted with `STATUS:CANCELLED`.
- **FR-25** An Owner can revoke any individual token; a revoked feed returns 404.
- **FR-26** Feed responses set caching headers appropriate to a roughly hourly poll.

### Admin authentication

- **FR-27** Organizers sign in via a single-use email magic link. No passwords exist.
- **FR-28** Magic links expire 15 minutes after issue and are consumed on first use.
- **FR-29** A sign-in request for an unknown email produces the same visible response as a
  known one, and sends nothing. *(Prevents membership enumeration.)*
- **FR-30** Magic link requests are rate-limited per email and per hashed IP.
- **FR-31** Admin sessions are separate from guest sessions and expire after 7 days.
- **FR-32** Every console route and mutation re-verifies the session server-side. Client
  state is never trusted.

### Admin console

- **FR-33** The console lists upcoming occurrences and indicates, per field, whether the
  value is inherited from the series or explicitly overridden.
- **FR-34** Inherited-versus-overridden state is conveyed by text or an icon with an
  accessible name — never by color alone.
- **FR-35** Each overridden field offers a "revert to series default" action.
- **FR-36** Editing the series defaults updates every non-overridden occurrence.
- **FR-37** Occurrences can be cancelled and un-cancelled, with a reason.
- **FR-38** Venues can be created and edited, including kind (private home / public venue),
  approximate area, street address, and accessibility notes.
- **FR-39** An occurrence can be set to reveal its address only from a chosen date.
- **FR-40** An Owner can set a new guest passphrase, with a strength requirement and a
  clear warning that all guest sessions will end.
- **FR-41** An Owner can invite an organizer by email and assign a role.
- **FR-42** An Owner can change roles and remove organizers, subject to the §6 constraints.
- **FR-43** Every mutation writes an audit entry: actor, action, target, before/after, timestamp.
- **FR-44** Every authorization decision is enforced server-side. Hiding a button is
  presentation, never protection.
- **FR-45** All mutation inputs are validated with a schema at the server boundary before
  any database access.

### Requirements defined elsewhere

FR-46 onward are defined in the document that also carries their reasoning, rather than being
restated here. Full range is **FR-1 – FR-86**, no gaps.

| Range | Topic | Document |
|-------|-------|----------|
| FR-46 – FR-52 | Public privacy and transparency pages | `TRANSPARENCY-PAGES.md §2` |
| FR-53 – FR-56 | `/styleguide` route | `DESIGN.md §7` |
| FR-57 – FR-67 | Demo deployment, repo README, commits, licence | `PORTFOLIO.md` |
| FR-68 – FR-71 | Soft delete and encrypted backups | `OBSERVABILITY.md §8` |
| FR-72 – FR-74 | Web app manifest, no service worker, cookie-consent position | `LAUNCH.md §3–4` |
| FR-75 – FR-82 | Error taxonomy, `Result` types, error boundaries | `ERROR-HANDLING.md §8` |
| FR-83 – FR-85 | Craft-agnostic copy, gate tagline, palette switcher | `DESIGN.md §5, §7` |
| FR-86 | Craft-specific venue access prompts | `ACCESSIBILITY.md §4` |

---

## 9. Non-functional requirements

- **NFR-1** Largest Contentful Paint under 2.0s on a simulated 4G connection.
- **NFR-2** The guest details page performs at most two database queries.
- **NFR-3** Zero client-side JavaScript is required to read event details.
- **NFR-4** No third-party analytics, tracking, advertising, or font CDNs. Fonts are
  self-hosted. *(Privacy and performance, and it keeps the CSP tight.)*
- **NFR-5** A strict Content-Security-Policy with no `unsafe-inline` in production.
- **NFR-6** Structured logs that never contain passphrases, tokens, magic links, street
  addresses, or raw IP addresses.
- **NFR-7** All code TypeScript in `strict` mode. No `any` in application code.
- **NFR-8** CI must pass typecheck, lint, unit tests, e2e tests, and accessibility checks
  before merge.

---

## 10. Success metrics

Reviewed one month after launch.

| Metric | Target |
|--------|--------|
| Guests who ask "where is it this week?" in chat | Near zero |
| Time for an organizer to update a week | Under 60 seconds |
| Automated accessibility violations in CI | Zero |
| WCAG 2.2 AA manual audit findings | Zero blocking |
| Monthly infrastructure cost | $0 |
| Guest PII fields in the database | Zero |

---

## 11. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Shared passphrase is forwardable and its spread is unknowable | Medium | Rotation from the console; per-occurrence address hiding; stated plainly on the privacy page so nobody is misled |
| Private home addresses reach an unbounded audience | High | Addresses excluded from calendar feeds entirely; `revealAddressAt` gating; encrypted at rest; venue kind flag makes sensitivity explicit |
| Neon free tier suspends when idle, adding ~1s to a cold first query | Low | Acceptable for this traffic; if it grates, a cron ping keeps it warm |
| Sole Owner loses email access and is locked out | Medium | Two Owners recommended; a documented database-level recovery procedure |
| Vercel or Neon changes free-tier terms | Low | No vendor-specific code outside a thin adapter layer; documented migration path |
| Timezone and DST handling produces wrong times twice a year | High | Wall-clock time plus IANA zone stored, never a UTC instant; explicit DST-transition test cases |
| Scope creep into RSVPs and notifications | Medium | §4 non-goals are explicit; additions require a decision entry |

---

## 12. Delivery phases

Each phase ends with something deployed and working. Detail in BUILD-PLAN.md.

| Phase | Deliverable |
|-------|-------------|
| **0** | Repository, tooling, CI, deployment pipeline, accessibility harness. No features. |
| **1** | Passphrase gate and guest details view. The site becomes genuinely useful here. |
| **2** | Admin magic-link authentication and console shell. |
| **3** | Series and occurrence editing with inheritance UI. |
| **4** | Roles and server-side authorization. |
| **5** | Calendar subscription feeds. |
| **6** | Privacy page, security hardening, custom domain, launch. |

Phase 1 is deliberately deployable on its own: a working site whose content is
seeded directly in the database is more valuable than a half-built console.
