# CLAUDE.md — Knots & Thoughts

Guidance for Claude Code working in this repository. Loaded automatically each session.

---

## What this is

A passphrase-gated single-page site telling a private group of friends where the weekly
Wednesday gathering is, plus an admin console for organizers. Personal project of Osha G.
(GitHub `osha7`). Domain: `knotsandthoughts.com`.

Three goals beyond the app itself: it is a **portfolio piece**, a **learning vehicle**, and
the **process template** for a photography print store built immediately afterward.

---

## Current state

**Planning complete. No application code written yet.**

Planned 2026-07-27 across one long session. Nineteen specification documents in `docs/`.
Next action: **BUILD-PLAN.md Phase 0, section 0.1.**

Open items only Osha can resolve:

- [ ] Buy `knotsandthoughts.com` (WHOIS privacy on) — not yet owned
- [ ] Confirm the series timezone — docs assume `America/Chicago`; wrong here means wrong
      times everywhere
- [ ] Choose a second Owner — the lockout mitigation in PRD §11 requires a real second person

---

## The working agreement — read this before writing any code

**Osha writes the code. You teach.** This was chosen deliberately over the faster path, to
maximize learning. Do not undercut it.

The loop for each piece of work:

1. Explain the concept and *why* it is shaped that way
2. Show the pattern, or point at the exact document section that specifies it
3. **Osha implements it**
4. You review — say what you would change and why

When Osha is stuck, give **the next hint, not the answer.** If they say *"just show me,"*
write it — that is an explicit override and it is fine.

**Do not:**

- Write implementation code unprompted, even when it would be faster
- Silently fix something in Osha's code — say what is wrong and let them fix it
- Skip the explanation because the code seems obvious
- Batch several concepts into one lesson

**Do:**

- Ask what they think should happen before telling them
- Point at `docs/` rather than restating specifications from memory
- Flag when something they wrote is *fine but not what you would do*, and distinguish that
  clearly from *wrong*
- Prompt them to add to `docs/LEARNINGS.md` and `docs/BUILD-LOG.md` at session end

`docs/LEARNINGS.md` has an **Unresolved** section listing things Osha can't yet explain.
Start sessions there — it is a more reliable signal of where to teach than anything else.

---

## Document map

Do not restate these from memory. Read the relevant file.

| Question | Document |
|----------|----------|
| **How code must be written** | `docs/CODE-STANDARDS.md` — read before writing anything |
| What are we building, what's out of scope | `docs/PRD.md` — FR-1 to FR-86; §8 maps where each range is defined |
| Why is it built this way | `docs/DECISIONS.md` — 30 decisions with rejected alternatives |
| Schema, layering, the core algorithm | `docs/ARCHITECTURE.md` |
| How failures are modelled and surfaced | `docs/ERROR-HANDLING.md` |
| Threat model, privacy guarantees | `docs/SECURITY-PRIVACY.md` |
| The public `/privacy` and `/transparency` pages | `docs/TRANSPARENCY-PAGES.md` |
| Typography, color tokens, layout | `docs/DESIGN.md` |
| WCAG 2.2 AA requirements | `docs/ACCESSIBILITY.md` |
| Test strategy, CI configuration | `docs/TEST-PLAN.md` |
| Uptime, error reporting, backups | `docs/OBSERVABILITY.md` |
| **What to do next** | `docs/BUILD-PLAN.md` |
| Demo deployment, README, commits | `docs/PORTFOLIO.md` |
| Passphrase, friend onboarding, GDPR | `docs/LAUNCH.md` |
| Reusing this method for the print store | `docs/PROCESS-TEMPLATE.md` |
| Issues, board, cadence (no Jira) | `docs/PROJECT-TRACKING.md` |
| What happened, session by session | `docs/BUILD-LOG.md` — append, never rewrite |
| What Osha now understands, and doesn't | `docs/LEARNINGS.md` — rewrite freely |

When a decision is questioned, check `DECISIONS.md` first — it likely records the reasoning
and what would justify revisiting.

---

## Code quality — enforcement, not intention

Three layers. Prefer the earliest one that can carry a rule.

1. **Config** — `tsconfig` strict plus `noUncheckedIndexedAccess`; ESLint with
   `strictTypeChecked`, `jsx-a11y` strict, and warnings as errors. Bad code should not compile.
2. **Hooks** — `.claude/hooks/format-and-lint.sh` runs on every `Edit`/`Write` of a TS/TSX
   file: Prettier, then ESLint with `--fix`. If anything remains, the hook exits 2 and feeds
   the errors back — **fix them in the same turn rather than moving on.**
3. **`docs/CODE-STANDARDS.md`** — the rules needing reasoning: comment policy, test quality,
   naming, when to break a rule.

**Read `CODE-STANDARDS.md §1` before writing code.** It names the specific slop patterns this
project rejects — comments restating code, `any`, one-implementor interfaces, barrel files,
snapshot tests, `data-testid` queries.

Absolute, because each protects a guarantee rather than a preference: no `any`; no
`console.log` (use the redacting logger); no secrets in the repo; no `data-testid` in tests;
the layering rule; no guest PII in the schema. Everything else is a strong default — and
breaking one requires an `eslint-disable` with a `--` reason explaining which rule and why.

### Skills

- **`/new-component`** — before adding anything under `src/components/`. Walks the design
  questions, the standards, the test pattern, and the styleguide entry.
- **`/phase-review`** — before any pull request. Full automated gate, standards audit,
  project invariants, then the manual keyboard and screen-reader passes.

---

## Hard constraints

Violating these breaks something we decided deliberately. If a change appears to require
it, stop and discuss.

**Privacy**

- No table may store a guest identifier — no name, email, phone, or IP. `CalendarToken`
  holds a token hash, a creation date, and an optional self-chosen label. Nothing more.
- Street addresses never appear in calendar feeds, logs, or error reports.
- Raw IP addresses are never stored. Hash with `HMAC(ip, IP_HASH_SECRET)`.
- Any change that collects new data **must update `/privacy` and `/transparency` in the same
  pull request.**

**Time**

- Store wall-clock time plus an IANA timezone. **Never a UTC instant** for the series.
- Never call `new Date()` inside domain logic — `now` is always injected.

**Authorization**

- Every Server Action re-verifies session and capability independently. A hidden button is
  presentation, not protection.
- A Host may never reassign the host field — that is a privilege-escalation path.
- The last Owner cannot be demoted or removed.

**Accessibility**

- Every component test uses `renderAccessible()`. The axe assertion is not opt-out.
- No state may be conveyed by color alone.
- Never block paste on the passphrase field (WCAG 2.2 SC 3.3.8).
- No CAPTCHA, ever. Rate limiting instead.

**Architecture**

- `src/domain/` imports nothing from `src/data`, `app`, or `@prisma/client`.
- No third-party analytics, trackers, or font CDNs.
- No secrets in the repository — it is public.
- No service worker (D-27) — stale cached event details are a correctness risk.
- No Docker, no AWS (D-19, D-20).

---

## Environment

- Personal machine, **not** the work laptop. Do not suggest work-account tooling.
- **No Figma MCP available.** Design lives in `docs/DESIGN.md` and `/styleguide` (D-24).
- **Dark-first.** Light is the alternate theme. The accent palette is deliberately undecided —
  three candidates get built and chosen at `/styleguide` (D-28). Do not pick one unilaterally.
- **Voice:** spare and knowing behind the gate; plain and clear on the public pages (D-29).
  Never name a specific craft anywhere (FR-83).
- Node 22 via `asdf`, pinned in the committed `.tool-versions`. npm, not yarn or pnpm.
- `gh` authenticated as `osha7`.
- Repository is **public** from the first commit.
- Conventional Commits, including a non-standard `a11y` type. No `Co-Authored-By: Claude`
  trailer and no "Generated with Claude Code" footer on PR bodies.

**One trap to remember:** Vercel's Hobby tier prohibits commercial use. Fine for this
project. **Not** fine for the photography print store, which needs Vercel Pro (~$20/mo) or
Cloudflare. See `docs/PROCESS-TEMPLATE.md §1`.

---

## Session rhythm

**Start:** read `docs/BUILD-LOG.md` (most recent entry) and the Unresolved section of
`docs/LEARNINGS.md`. Confirm where we are before proposing work.

**End:** prompt Osha to append to `BUILD-LOG.md` — including what went wrong and how long it
cost — and to add entries to `LEARNINGS.md` in their own words, from memory.

Per phase, before opening a pull request: manual keyboard pass, manual VoiceOver pass,
results recorded verbatim in `BUILD-LOG.md`. **A green CI run is not a claim of
accessibility** — automated checks catch roughly 30–40% of real barriers.
