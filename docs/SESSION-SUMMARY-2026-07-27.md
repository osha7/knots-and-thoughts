# Session Summary — 27 July 2026

Planning session for **Knots & Thoughts**. Written as a standalone recap to travel with the
archive — readable without any of the other documents.

**Outcome:** complete specification, no application code. Ready to begin Phase 0 on personal
hardware.

**Author:** Osha G. (GitHub `osha7`)

---

## 1. What you started with

A one-paragraph idea: a password-protected page telling friends where the weekly Wednesday
craft night is being held, with an admin console for organizers, free hosting, accessibility at
the core, TypeScript throughout, tested end to end, and documented well enough to repeat the
whole process for a photography print store afterward.

The group is a stitch-and-bitch — all crafts welcome, weekday evening, forty-ish people, venues
alternating between private homes and public spaces.

---

## 2. What you have now

**20 documents, 41,371 words, 6,296 lines** in `~/Documents/knots-and-thoughts/`, plus four
files under `.claude/`. Zero lines of application code — deliberately, because Phase 0 belongs
on your own machine.

| Category | Documents |
|----------|-----------|
| **Product** | `PRD.md` — 86 numbered testable requirements, 4 roles with a full permission matrix, 8 user journeys, non-goals split into *permanently out* vs. *deferred* |
| **Rationale** | `DECISIONS.md` — 30 decisions, each with rejected alternatives and revisit conditions |
| **Technical** | `ARCHITECTURE.md` (schema, layering, resolution algorithm), `ERROR-HANDLING.md`, `CODE-STANDARDS.md`, `TEST-PLAN.md`, `OBSERVABILITY.md` |
| **Constraints** | `SECURITY-PRIVACY.md`, `ACCESSIBILITY.md`, `DESIGN.md`, `TRANSPARENCY-PAGES.md` |
| **Execution** | `BUILD-PLAN.md` (7 phases from a bare laptop), `PROJECT-TRACKING.md`, `LAUNCH.md`, `PORTFOLIO.md` |
| **Continuity** | `CLAUDE.md` at repo root; `.claude/` with a format-and-lint hook, permissions, and two skills |
| **Learning** | `BUILD-LOG.md` (chronological), `LEARNINGS.md` (topical), `PROCESS-TEMPLATE.md` (for app #2) |
| **This file** | `SESSION-SUMMARY-2026-07-27.md` |

`README.md` is the index and includes the machine-transfer procedure.

---

## 3. The decisions

Full reasoning and rejected alternatives in `DECISIONS.md` (D-01 … D-30).

**Stack.** Next.js App Router with TypeScript in strict mode, Prisma against Neon Postgres,
hosted on Vercel, mutations through Server Actions. Free at this scale; ~$12/year for the
domain is the only recurring cost.

**Authentication.** Magic links for organizers — nothing to hash, rotate, or leak, and it
satisfies WCAG 2.2 SC 3.3.8 cleanly by avoiding a cognitive function test. For guests, an
Argon2id-hashed shared passphrase with a version-stamped session cookie, so rotating the
passphrase invalidates every session instantly with no session table to purge.

**Data model.** A `series` row holds the weekly defaults; an `occurrence` row exists only for
weeks that differ, where `null` means inherit. Changing the standing time permanently is a
one-field edit rather than 52. Time is stored as wall-clock plus an IANA timezone, never a UTC
instant, so the event stays at 7 PM local through daylight saving transitions.

**Roles.** Owner, Editor, Host, Viewer — an explicit capability matrix rather than hierarchical
levels, because "Host may edit only their own week" is row-level authorization. Three deliberate
guardrails: the last Owner cannot be demoted or removed, an Owner cannot change their own role,
and a Host cannot reassign the host field (a privilege-escalation path).

**Privacy.** Zero guest PII by construction. Calendar subscriptions use anonymous
high-entropy tokens stored only as hashes — no email, no name, no IP. There is no subscriber
table, and the repository is public so that claim is verifiable rather than asserted.

**Design.** Dark-first, modern, private. Three candidate palettes to be chosen in the browser
at `/styleguide` rather than from hex codes.

**Testing.** Vitest, Playwright, and axe-core. Accessibility is a separately named blocking CI
job so failures read as `accessibility — failing` rather than being buried inside `e2e`.

**Deliberately excluded, each with recorded reasoning:** Docker, AWS, Sentry, SMS, service
workers, Figma, sprints, CAPTCHAs, third-party analytics.

---

## 4. Six catches worth the session

Problems found now instead of at hour forty. This is what the planning bought.

**1. The Figma account is an employer's enterprise organization.** Personal design assets in an
employer-administered org disappear when employment does, and hand over a plausible ownership
claim. Separately, the Figma MCP will not exist on the build machine. Two independent
disqualifications — design moved to code, with `/styleguide` as the living artifact.

**2. Vercel's Hobby tier prohibits commercial use.** Fine for this project. It means the
photography print store is **not a free project** — it needs Vercel Pro (~$20/month) or a move
to Cloudflare/Netlify. This is in the acceptable-use terms, not the pricing page.

**3. Sentry would have leaked subscriber credentials.** Calendar feed URLs are bearer tokens,
and Sentry captures request URLs — so default configuration would have copied every
subscriber's access token into a third party's database. Error reports now stay in our own
database with tokens scrubbed before write.

**4. The passphrase gate hides the portfolio piece.** A reviewer follows a portfolio link, hits
a password field, and leaves. Fixed with a separate demo deployment on its own database branch,
passphrase printed on the gate, seeded with obviously fictional data covering every interesting
state.

**5. Uptime monitoring matters more than error reporting.** If Neon has an outage, nothing
throws anywhere — the site is simply dead and you learn about it from a friend on Wednesday
evening. It is the higher-value investment and is almost always built last.

**6. Specifying the palette surfaced a live conformance bug.** One candidate's border computes
≈1.9:1 against the 3:1 that SC 1.4.11 requires. It is left in `DESIGN.md` uncorrected on
purpose, as a worked example of exactly how dark themes fail — a border that looks fine and is
not conformant.

---

## 5. Three ideas the whole plan rests on

**Structural guarantees beat behavioural promises.** "We won't share your data" depends on
continued good behaviour by everyone who ever touches the code, and you cannot check it.
"There is no subscriber table" is a fact anyone can verify. That reframing produced the
zero-PII schema, the public repository, and the *what we cannot promise* section on the privacy
page — which names four things that are genuinely not true, including that Google Calendar
subscribers' feeds are fetched and retained by Google.

**If a rule depends on being remembered, it will eventually be forgotten.** So: a
`renderAccessible()` helper runs axe on every component test with no opt-out; a meta-test fails
when any component lacks a test file; a hook formats and lints every file on write; redaction
lives in the logger rather than at call sites; the domain layer's purity is enforced by a lint
rule. Encode rules in tests, types, and tooling — not in prose.

**Accessibility means who can actually attend, not whether the markup validates.** The clearest
case: venue access notes rewritten around what a three-hour handwork evening actually requires —
**light** first (fine stitching is impossible without it, and no checklist mentions it), seating
with back support, table surface, **noise level** (a hard-surfaced room with fifteen talkers is
inaccessible to a hard-of-hearing guest), and pets. Nine seconds to write; changes who can come.

---

## 6. Deliberately unresolved

**The accent palette.** Three dark candidates — ink & brass, obsidian & ice, deep indigo &
bone — to be judged at `/styleguide` with real content on screen. Choosing colour from hex
codes is guesswork. Build the three *dark* sets first, pick one, then derive its light
counterpart.

**A second Owner.** The lockout mitigation requires a real second person, not a placeholder.

**The `LEARNINGS.md` Unresolved list.** Six honest entries, including "I can't explain why
Server Actions are public endpoints — I'm repeating it from the docs." That is a feature, not a
gap: it is the agenda for the first working session, and a more reliable signal of where to
teach than any confident summary.

---

## 7. The working agreement

**Osha writes the code. Claude teaches.** Chosen deliberately over the faster path.

The loop: explain the concept and why it is shaped that way → show the pattern or point at the
exact spec section → Osha implements → review and say what would change and why. When stuck,
the next hint rather than the answer. Saying *"just show me"* is an explicit override.

Estimated 60–80 hours across seven phases. Phase 0 ships nothing visible, which is correct —
retrofitting a CI accessibility gate onto forty components is a miserable week; adding it to one
placeholder is twenty minutes, and every later phase inherits it.

This agreement lives in `CLAUDE.md`, which Claude Code loads automatically every session. It is
the mechanism that carries the decision across a context reset.

---

## 8. Picking up on the new machine

1. `brew install jq` — the format-and-lint hook silently no-ops without it
2. **Buy `knotsandthoughts.com`**, WHOIS privacy on. Do this first so DNS propagation and
   Resend domain verification are never on the critical path
3. **Confirm the series timezone.** Six documents assume `America/Chicago`. This is the one open
   item that produces *wrong output* rather than a missing feature — wrong here means everybody
   sees the wrong time
4. Transfer per `README.md`. Copy the **whole folder** — `.claude/` is hidden and easy to lose.
   `CLAUDE.md` goes at the repository root; everything else into `docs/`
5. Verify the handoff: open Claude Code and ask *"what's our working agreement?"* If it does not
   say you write the code, `CLAUDE.md` landed in `docs/` instead of the root
6. Start with Server Components versus Server Actions, before any setup — roughly six
   requirements exist *because* of how Server Actions work, and they read as ceremony until that
   clicks

Then work from `BUILD-PLAN.md §0.1`, and append to `BUILD-LOG.md` every session — including what
went wrong and how long it cost. That is the artifact that makes the print store faster than
this one.

---

## 9. Cost

| Item | Cost |
|------|------|
| Domain `knotsandthoughts.com` | ~$11–15 / year |
| Vercel Hobby, Neon, Resend, GitHub, UptimeRobot | $0 |
| **Total** | **~$12 / year** |

The domain is the only recurring cost. Nothing here is a trial that expires — but note catch #2
above: this holds for a personal project, and **not** for the commercial print store.
