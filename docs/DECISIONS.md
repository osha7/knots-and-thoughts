# Decision Log

Every significant choice, the alternatives considered, and the reasoning. Written so
that a future reader — including you in six months, or you building the photography
print store — can tell which decisions were principled and which were merely
convenient.

Format: decision, alternatives rejected, reasoning, and what would make us revisit it.

---

## D-01 — Next.js with TypeScript

**Alternatives:** Remix, SvelteKit, Astro, plain React + Express.

**Reasoning:** Next.js gives server-rendered HTML by default, which directly serves
FR-18 (details readable without JavaScript) and the accessibility goal. It has the
largest body of available answers when something breaks, and it is the stack that
transfers most cleanly to the photography print store, which will want image
optimization and incremental static regeneration. TypeScript throughout was a
stated requirement.

**Revisit if:** The project grows a substantial non-web surface.

---

## D-02 — App Router, not Pages Router

**Alternatives:** Pages Router (which the author uses at work).

**Reasoning:** Server Components keep data fetching on the server, so event details
never require a client round trip. Server Actions give progressively-enhanced forms
that work without JavaScript — a real accessibility benefit, not a theoretical one.
App Router is where Next.js development is going, so the knowledge is more durable.

**Cost acknowledged:** Different from the author's day-to-day Pages Router habits.
Worth the friction on a greenfield project.

---

## D-03 — Vercel for hosting, Neon for Postgres

**Alternatives considered in detail:**

- **Cloudflare Pages + D1** — technically tidier: always free, no database
  suspension, faster edge delivery. Rejected because Next.js on the Workers runtime
  still requires the OpenNext adapter and has Node API gaps. That friction is a poor
  use of a first project's budget.
- **Supabase + Vercel** — least code for auth since it is built in. Rejected because
  Supabase pauses free projects after 7 days of inactivity, which is precisely the
  failure mode a low-traffic friends' site hits. A site that is down when someone
  checks it on Wednesday has failed at its only job.
- **Netlify + Turso** — perfectly workable. Rejected as a less-travelled combination
  for Next.js; fewer available answers when something breaks.

**Reasoning:** Best developer experience, free auto-renewing TLS, custom domain
support, and it transfers directly to the print store.

**Cost acknowledged:** Neon's free tier suspends after inactivity, adding roughly a
second to the first query after a quiet period. Acceptable here.

---

## D-04 — Prisma as the ORM

**Alternatives:** Drizzle, Kysely, raw SQL.

**Reasoning:** Drizzle is arguably the better technical fit for serverless — smaller,
no engine binary, faster cold start. That advantage is noise at this traffic level.
Prisma wins on two grounds that matter more here: the author already knows it deeply
from professional work, and its migration tooling and Studio make the *documented,
repeatable process* substantially easier to write down. Novelty budget is better spent
on accessibility and testing.

**Revisit if:** Cold-start latency becomes measurably user-visible.

---

## D-05 — Admin authentication by email magic link

**Alternatives:**

- **Username + password** — self-contained, no third-party email dependency.
  Rejected: more security surface we own, plus password reset flows to build and test.
- **OAuth via Google or GitHub** — fastest to build. Rejected: requires every
  organizer to have and use one of those accounts, and ties site access to a third
  party's account decisions.
- **Passkeys / WebAuthn** — strongest security, good accessibility. Rejected: recovery
  flows are genuinely fiddly, and locking the only Owner out of their own site with no
  path back is a worse outcome than the marginal security gain.

**Reasoning:** Nothing to hash, rotate, or leak. Nothing for organizers to remember.
Notably, magic links satisfy WCAG 2.2 SC 3.3.8 (Accessible Authentication) cleanly by
avoiding any cognitive function test.

**Cost acknowledged:** Depends on Resend and on organizers' email access. Mitigated by
recommending two Owners and documenting database-level recovery.

---

## D-06 — Guest access by shared passphrase, Argon2id hashed

**Alternatives:**

- **Rotating weekly code** — a leak expires quickly. Rejected: real friction for
  friends every single week, for a threat model that does not warrant it.
- **Per-person invite links** — revocable individually, and you would know who leaked.
  Rejected: drifts toward the per-user authentication that was explicitly not wanted.

**Reasoning:** Simplest possible thing for guests — nothing to sign up for, nothing to
install. Argon2id rather than bcrypt because it is the current password-hashing
recommendation and resists GPU attack better.

**Stated honestly:** This is obscurity with a speed bump, not security. Anyone with the
passphrase can forward it and we will never know. That is acceptable for "where is the
hangout" and it is written plainly on the privacy page rather than papered over. It is
*not* acceptable as the only protection for a private home address, which is why
addresses have separate gating (D-11).

---

## D-07 — Series plus occurrence overrides for the data model

**Alternatives:**

- **Single current-event row overwritten weekly** — ships fastest. Rejected: no history,
  no next-week preview, which contradicts the chosen guest view.
- **Flat list of independent dated rows** — no merge logic, trivially testable. Rejected:
  someone creates ~52 near-identical rows a year, and "change the standing time" becomes
  52 edits with inevitable misses.

**Reasoning:** A `series` row holds defaults; an `occurrence` row exists only for weeks
that differ, where `null` means inherit. Changing the standing time permanently is a
one-field edit. The merge is a pure function, which makes it exhaustively unit-testable.

**Explicit scope limit:** This is defaults-plus-exceptions, *not* an RFC 5545 recurrence
engine. No `RRULE` parsing, no arbitrary recurrence patterns.

**Cost acknowledged:** Two tables and a merge function. Admin UI must communicate
inherited-versus-overridden state clearly, which is real design work.

---

## D-08 — Store wall-clock time plus IANA timezone, never a UTC instant

**Alternatives:** Store UTC timestamps and convert on display.

**Reasoning:** The event is "7:00 PM Central every Wednesday," not "an instant." Storing
`19:00` plus `America/Chicago` means it stays 7:00 PM local through daylight saving
transitions. Storing UTC makes the event silently jump an hour twice a year — an
extremely common bug that is genuinely annoying to retrofit.

**Consequence:** DST-transition weeks get explicit test cases (TEST-PLAN.md §3).

---

## D-09 — Times displayed in the series timezone, explicitly named

**Alternatives:** Convert to the viewer's local timezone.

**Reasoning:** Everyone attending is physically in the same place. Converting to the
viewer's zone actively misleads a friend checking from a hotel in another state —
they'd see a time that isn't when to show up. Naming the zone ("7:00 PM Central")
removes the ambiguity without the misdirection.

---

## D-10 — Four roles as an explicit capability matrix

**Alternatives:** Two roles (Owner + Editor); a full granular permission matrix.

**Reasoning:** Owner, Editor, Host, and Viewer were requested. Implemented as an
explicit capability table rather than hierarchical levels, because "Host may edit
*only their own* week" is row-level authorization and cannot be expressed as a level.
A full per-capability grant system was rejected as substantial design and test surface
for a problem this site does not have.

**Guardrails:** The last Owner cannot be demoted or removed; an Owner cannot change
their own role; a Host cannot reassign the host field. Each is a privilege-escalation
or lockout path closed deliberately.

---

## D-11 — Anonymous calendar feed tokens with zero stored PII

**Alternatives:**

- **One shared feed URL** — nothing stored at all. Rejected: if it escapes, the only
  remedy is rotating for everyone simultaneously.
- **Email-based subscription** — enables change notifications. Rejected for v1: requires
  collecting email addresses, which contradicts the zero-PII goal. Deferred as a
  deliberate future decision rather than a quiet addition.

**Reasoning:** The strongest privacy guarantee is structural, not behavioural. "We will
not share your data" depends on continued good behaviour. "There is no subscriber table"
is a fact anyone can verify. Subscribing generates a high-entropy token; we store only
its SHA-256 hash and a creation date. No email, no name, no IP. There is nothing to leak
because nothing was collected.

---

## D-12 — Street addresses never appear in calendar feeds

**Reasoning:** Google Calendar and Outlook.com fetch subscription feeds from *their own
servers*, not the user's device. Anything in the feed is retained by those providers. A
feed containing a private home address would quietly publish it to third-party
infrastructure weeks in advance, defeating the `revealAddressAt` gating entirely.

Feeds carry venue *name* and a link back to the site. The address lives only on the
passphrase-gated page.

---

## D-13 — Public source repository

**Reasoning:** It converts "we don't collect your data" from an assertion into something
verifiable. Anyone can read the schema and confirm there is no subscriber table. This is
the highest-trust move available and it costs nothing.

**Requirement it creates:** No secrets in the repository, ever. All configuration through
environment variables, validated at startup.

---

## D-14 — Vitest, Playwright, and axe-core

**Alternatives:** Jest (used at the author's work), Cypress.

**Reasoning:** Vitest is materially faster and has better native TypeScript and ESM
handling, which matters when tests run on every save. Playwright handles multiple browser
engines and has the better accessibility-tree inspection. `axe-core` runs in both layers
so violations fail the build rather than getting logged and forgotten.

**Position taken:** Automated checks catch perhaps 30–40% of real accessibility problems.
They are a floor, not a ceiling. Manual keyboard and screen-reader passes are required
per phase and recorded in BUILD-LOG.md.

---

## D-15 — Rate limiting in Postgres, not Redis

**Alternatives:** Upstash Redis free tier.

**Reasoning:** In-memory rate limiting cannot work on serverless. A small Postgres table
holding hashed IP plus timestamp is sufficient at this scale and avoids a fourth vendor.
Rows older than 24 hours are deleted, so it does not accumulate.

**Privacy note:** The stored value is `HMAC(ip, server_secret)`, not the address itself —
so the table cannot be used to reconstruct who visited.

**Revisit if:** Traffic grows enough that the write volume matters.

---

## D-16 — No third-party analytics, trackers, or font CDNs

**Reasoning:** Serves privacy, performance, and a tight Content-Security-Policy
simultaneously. Self-hosted fonts also eliminate a layout-shift source and a
render-blocking third-party request.

**Consequence:** No usage data. Accepted deliberately — success metrics are observational
("does anyone still ask in chat?") rather than instrumented.

---

## D-17 — HTTPS only

**Reasoning:** A passphrase form over plain HTTP transmits that passphrase in cleartext to
anyone sharing the network. Every candidate host issues free auto-renewing certificates.
There is no tradeoff to weigh. HTTP is permanently redirected; HSTS is set.

---

## D-18 — Server Actions for mutations

**Alternatives:** REST route handlers with client-side fetch.

**Reasoning:** Progressively-enhanced forms that function without JavaScript, which is
both an accessibility and a robustness win. Less client code, fewer loading states to
manage, and no API surface to version.

**Requirement it creates:** Server Actions are public endpoints. Every one must
independently re-verify session and authorization — FR-32 and FR-44 exist because of
this.

---

## D-19 — Docker not used

**Alternatives:** Docker Compose for local Postgres, as `loop-api` does at work.

**Reasoning:** Docker earns its place for reproducible multi-service local development and
for production parity. Neither applies. Production is Vercel's serverless runtime, which
**cannot** run in a container — so Docker would not provide parity, it would provide a
*confidently different* environment, which is worse than none because it invites trust in
local behaviour that does not transfer.

The only backing service is Postgres, and Neon's free database branches
(`neonctl branches create`) give a real branch on the identical engine and version. That is
strictly better than local Docker Postgres at the same zero cost.

**Calibration:** `loop-api` correctly uses Docker Compose — it runs Postgres, Redis, BullMQ
workers, and an API server. Four services with startup ordering is exactly Docker's
problem. One managed database is not.

**Revisit if:** A long-running background worker appears — likely for the print store.

Full reasoning in OBSERVABILITY.md §1.

---

## D-20 — AWS not used

**Alternatives:** Lambda + API Gateway + RDS + CloudFront + Route 53.

**Reasoning:** The free tier is the trap. Most AWS free-tier allowances run 12 months and
then bill — RDS especially. Choosing AWS would plant a cost landmine that detonates a year
in, breaking the zero-cost requirement on a delay rather than immediately. It is also not
free on day one: Route 53 charges $0.50/month per hosted zone. And the assembly is roughly
twenty times the setup effort of Vercel + Neon, with IAM and VPC configuration as the
reward, for a site displaying one event per week.

**Revisit for the print store, with a caveat:** high-resolution image serving does want
object storage, but prefer **Cloudflare R2** over S3 — R2 charges no egress, and image
serving is nearly all egress.

---

## D-21 — Self-hosted error reporting rather than Sentry

**Alternatives:** Sentry free tier (5,000 errors/month, excellent Next.js SDK); Better
Stack; Axiom; GlitchTip.

**Reasoning:** Sentry captures request URLs. One of this application's URLs is
`/api/calendar/{token}.ics`, and **that token is a bearer credential** — whoever holds it
can read the feed. Sending those URLs to Sentry would store subscribers' access tokens in
a third party's database. It is fixable with `beforeSend` scrubbing, but it is exactly the
class of thing that breaks quietly during a refactor, and it directly undercuts the
guarantee D-11 and D-13 went to real effort to make structurally true.

So: an `ErrorReport` table deduplicated by fingerprint, plus a 15-minute Vercel Cron job
sending one digest email through Resend — a vendor already in use, so no new third party
and no email storm when something loops.

**Cost acknowledged:** No source-map symbolication and no release tracking. Server-side
Next.js stack traces are readable without symbolication, so the practical loss is confined
to client-side errors.

**Related insight worth recording:** for a site like this, **uptime monitoring matters more
than error reporting.** If Neon has an outage nothing throws — the site is simply dead and
you learn about it from a friend on Wednesday evening. The health endpoint plus a free
uptime monitor is the higher-value investment, and it is usually built last.

Full design in OBSERVABILITY.md.

---

## D-22 — Privacy and transparency pages are public, outside the passphrase gate

**Alternatives:** Behind the gate; a single combined page; a footer link only.

**Reasoning:** Gating the explanation of what you collect behind the very thing you are
asking people to trust is backwards. Somebody deciding whether to type a passphrase into
an unfamiliar site should be able to read the policy *first*. Both pages are therefore
public, linked from the gate itself before any credential is requested, and are the
deliberate exception to the site-wide `noindex` rule — there is no reason to hide a privacy
policy from a search engine, and a policy nobody can find is not transparency.

Two pages rather than one because the audiences differ: `/privacy` is ~400 words of plain
language that a friend will actually read on a phone; `/transparency` is the full
reasoning for anyone who wants it.

**On publishing the security design:** describing how the authentication and encryption
work does not weaken them. Kerckhoffs's principle — a system whose security depends on its
own design being secret is not secure. The keys stay secret; the design is already public
in the repository.

**Standing rule this creates:** any change that causes new data to be collected must update
both pages **in the same pull request**. Otherwise the page silently becomes a false
statement, which is worse than never having made the promise.

Draft copy in TRANSPARENCY-PAGES.md.

---

## D-23 — Accessibility and component test coverage enforced mechanically

**Alternatives:** Convention and code review; a documented checklist.

**Reasoning:** A rule that depends on someone remembering it will eventually be forgotten.
Two devices make the requirements structural instead:

1. **`renderAccessible()`** — a render helper that runs axe and asserts zero violations on
   every use. There is no way to write a component test that skips the accessibility
   assertion, because the assertion lives in the helper rather than in the test.
2. **`tests/meta/coverage.test.ts`** — enumerates `src/components/**/*.tsx` and fails if
   any lacks a sibling test file. Coverage of *existence* is enforced rather than
   remembered.

Together these yield *every component has an accessibility test* by construction.

Accessibility is additionally a **separately named CI job**, so a failure reads
`accessibility — failing` rather than being buried inside `e2e — failing`. Naming the
failure is what makes it get fixed instead of retried.

**The same principle applied elsewhere:** redaction is enforced in the logger rather than
at call sites; the domain layer's purity is enforced by `no-restricted-imports` rather than
by discipline.

**Stated limitation:** automated checks catch roughly 30–40% of real accessibility
barriers. They are a regression floor, not evidence of an accessible product. Manual
keyboard and screen-reader passes are required per phase and recorded in BUILD-LOG.md. A
green CI run is explicitly not a claim of accessibility.

---

## D-24 — Design in code, not Figma; `/styleguide` as the living design system

**Alternatives:** Design in Figma first and implement from it; a hybrid with tokens and two
key screens in Figma.

**Reasoning:** Two independent disqualifications, either sufficient on its own.

1. **The only available Figma account is a work account on an employer's enterprise
   organization.** Putting a personal project's design assets in an employer-administered
   Figma org has the same problem as building on the employer's laptop, and arguably worse —
   access disappears when employment does, and it hands the employer a plausible ownership
   claim over the assets. Especially relevant given the photography print store follows.
2. **The Figma MCP will not exist on the build machine.** The project is being transferred to
   personal hardware where the integration is unavailable, so any Figma-dependent workflow
   would break at the moment work actually starts.

**What replaces it, and why it is better here:** a `/styleguide` route inside the
application rendering every component in every state from the real tokens. For an
engineer's portfolio this beats a static mockup — it is running code, it is the natural
surface for the axe sweep to cover every component state at once, it doubles as a visual
regression target, and it lets components be built in isolation before being wired to data.

`DESIGN.md` is the specification; `/styleguide` is the implementation; README screenshots
are taken from it.

**Cost acknowledged:** No design artifact separate from the code, and less practice with a
tool that is genuinely useful to be able to read. Learning to *read* Figma remains worth
doing; learning to *draft* in it is a better separate project, on a personal account, once
this has shipped.

---

## D-25 — A public demo deployment, because the passphrase gate hides the portfolio piece

**The conflict:** the site is passphrase-gated, so a reviewer following a portfolio link
hits a password field and leaves. Nearly every reviewer follows the same path — live link,
then README, then maybe commits — so breaking the first step wastes the rest.

**Decision:** `demo.knotsandthoughts.com`, same codebase, **separate Neon branch**,
separate environment variables, passphrase printed on the gate itself. Seeded with
unmistakably fictional data that covers every interesting state: an inherited week, an
overridden week, a cancelled week, a hidden address, and venue accessibility notes. Seeded
Owner and Host logins published in the README so a reviewer can see the authorization
difference themselves.

**Alternatives rejected:** screenshots and a screen recording only (weaker — reviewers
discount static images); publishing the real passphrase (unacceptable, it protects home
addresses); removing the gate (defeats the product).

**Why the separate database matters:** a reviewer poking at the demo must not be able to
reach a real address. Same code, different data, enforced by configuration rather than by
care.

---

## D-26 — Soft delete plus weekly encrypted logical backup

**Gap this closes:** Neon's free tier point-in-time restore covers "I broke it ten minutes
ago," not "I deleted every venue last Tuesday." The console has no undo.

**Decision:** two layers. `deletedAt` soft deletes on `Venue`, `Organizer`, and
`Occurrence`, filtered in the repository layer rather than at call sites. Plus a weekly
GitHub Action running `pg_dump`, encrypted with `age` before upload, retained 90 days.

**Why encrypt the dump:** it contains street addresses. GitHub artifacts on a public repo
are not themselves public, but an unencrypted dump of home addresses in CI storage is a poor
bet. Asymmetric encryption means the workflow encrypts without holding the decryption key —
which lives in a password manager, not in GitHub secrets, because a backup decryptable from
the same place that was compromised is not a backup.

**Restore must be tested once before launch.** An untested backup is a guess — the same
principle as testing the uptime alert by actually breaking the site.

**Limitation stated:** worst-case loss is seven days of schedule edits. Acceptable for a
weekly event held in one series row plus a few overrides. **Not** acceptable for the print
store, which needs daily or continuous backup once orders exist.

---

## D-27 — No service worker

**Alternatives:** A service worker for offline support, as most PWA guidance recommends.

**Reasoning:** A service worker would cache event details, and **stale cached details are
worse than a slow load** — someone could be shown last week's address and drive to the wrong
house. The site's entire purpose is being correct about where to go.

A web app manifest and icons are still included, so add-to-home-screen works and the site
opens without browser chrome. That is the part of PWA behaviour worth having here; offline
caching is actively harmful.

**Revisit if:** the site ever gains content where staleness is harmless. Event details are
not that.

---

## D-28 — Dark-first, with the palette chosen in the browser rather than on paper

**Context:** the group is a stitch-and-bitch — all crafts welcome, weekday evening, social. The
original direction (warm cream paper, madder and indigo, botanical restraint) was rejected as
reading folk-craft and hippy rather than private and modern.

**Two decisions here.**

**Dark is the default theme; light is the alternate.** This is the largest lever in the design,
larger than the accent colour. Warm paper reads *welcoming*, which is the opposite of the
intent; near-black behind a passphrase gate reads *you are inside something now*. The gate is a
threshold and the palette should mark it.

Light remains available under `prefers-color-scheme: light` — forcing dark on someone who has
asked for light is hostile, and is an accessibility problem for people with astigmatism, for
whom light-on-dark text can smear.

**The accent colour is deliberately undecided.** Three dark candidates (ink & brass, obsidian &
ice, deep indigo & bone) get built as swappable token sets, and the choice happens at
`/styleguide` against real content. Choosing a colour from hex codes in a terminal is guesswork;
twenty extra minutes in Phase 0 buys a decision made with pixels.

**Sequencing that follows:** build the three *dark* candidates, choose one, *then* derive its
light counterpart. Three candidates × two themes would be six token sets to contrast-validate;
this halves it, and dark is the default so it is the right thing to judge on.

**A finding worth preserving:** candidate A's `--border` at `#2E323C` computes ≈1.9:1 against its
surface and **fails SC 1.4.11's 3:1 requirement.** It is left in `DESIGN.md §3` uncorrected on
purpose, because it is exactly how dark themes fail — a border that looks fine and is not
conformant. Every candidate's border and focus values must be computed and lifted *before* the
palettes are compared, so the choice is among three conformant options rather than three pretty
ones.

**The switcher is development-only.** Production ships one palette plus `prefers-color-scheme`.
It must not become a user-facing theme picker — that needs persistence, a flash-of-wrong-theme
fix, and its own accessible control, for a preference the OS already reports.

---

## D-29 — Split voice register: wry behind the gate, plain on public pages

**Reasoning:** the two audiences genuinely differ, and one register cannot serve both.

Behind the passphrase, the readers are forty friends at a craft night. Spare, knowing, no
exclamation marks — *"Enter the passphrase."* and *"That's not it."* rather than *"Oops! That
passphrase didn't work."* Confident rather than chatty, matching the dark aesthetic.

`/privacy` and `/transparency` are deliberately public and search-indexable (FR-52), and are
also what a portfolio reviewer reads. They stay **plain**.

**The distinction that matters:** "spare" behind the gate means unfussy. On the public pages it
must never mean terse at the cost of clarity. Plain language there is an accessibility
requirement, not a style preference — it serves people with cognitive disabilities, non-native
readers, and anyone skimming on a phone. The existing draft copy in `TRANSPARENCY-PAGES.md` is
already correct and should not be tightened into cleverness.

**Craft-agnostic language everywhere** (FR-83). Never name a specific craft in any label,
placeholder, example, or error message — not "knitting," not "your knitting." A name containing
*Knots* could read as knitting-only to someone who crochets, embroiders, or whittles, so the gate
carries the tagline **"Bring whatever you're working on."** (FR-84). That line is the one place
the site states the premise.

---

## D-30 — Venue access notes are craft-specific, not a generic venue checklist

**Reasoning:** standard accessibility guidance — step-free entry, parking, restrooms — matters,
but it is not what determines whether someone can take part in a three-hour handwork evening. The
factors that actually decide it are **light** (fine stitching is impossible without it, and it is
the single most-omitted item), **seating with back support**, **table surface**, **noise level**
(a hard-surfaced room with fifteen talkers is inaccessible to a hard-of-hearing guest), and
**pets**.

The venue form prompts for each explicitly rather than offering one unguided freeform box
(FR-86), because a field with no prompt gets a generic answer or none at all.

This is the clearest case in the project of accessibility meaning *who can actually attend*
rather than *does the markup validate*. Full guidance in `ACCESSIBILITY.md §4`.
