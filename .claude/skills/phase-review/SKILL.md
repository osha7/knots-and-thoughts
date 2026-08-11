---
name: phase-review
description: Run the full pre-pull-request gate for a build phase — typecheck, lint, dead-code, all test suites, then walk the manual keyboard and screen-reader passes and prompt for BUILD-LOG and LEARNINGS entries. Use before opening any PR, at the end of a phase, or when the user says "phase review", "ready to merge", or "am I done".
---

# Phase Review

The gate before a pull request. Automated checks first because they are fast and objective;
manual passes second because they are the ones that actually catch barriers.

**Do not let Osha skip the manual passes.** Automated checks catch roughly 30–40% of real
accessibility problems. A green CI run is not a claim of accessibility, and this project
states that explicitly.

---

## 1. Automated — run these, report failures plainly

```bash
npm run typecheck        # tsc --noEmit, whole project
npm run lint             # warnings are errors
npm run format:check
npx knip                 # unused exports, files, dependencies
npm run test:unit -- --coverage
npm run test:integration
npm run test:e2e
npm run test:a11y
```

On failure: show the output, explain what it means, and let **Osha** fix it. Do not fix it
yourself — teaching mode applies (`CLAUDE.md` → working agreement).

Coverage thresholds per `TEST-PLAN.md §9`. `src/domain/**` must be **100%** — those are pure
functions with no excuse for gaps. If it is below, find the untested branch and ask Osha what
case it represents.

---

## 2. Standards audit — read the diff

`git diff main...HEAD`, then check against `CODE-STANDARDS.md`. Report findings; do not
silently correct them.

- [ ] No `any`, no `as` used to silence an error
- [ ] No comment that restates the code (§5)
- [ ] No `console.log` — the redacting logger instead
- [ ] No `TODO` or `FIXME` — an issue link or nothing
- [ ] No dead or commented-out code
- [ ] No `data-testid` or class-based queries in tests
- [ ] No snapshot tests
- [ ] Every `eslint-disable` carries a `--` reason (§10)
- [ ] Naming consistent with the domain language: series, occurrence, override, venue, host,
      organizer, guest
- [ ] Files under ~250 lines
- [ ] `src/domain/` still imports no I/O

**Then ask the review questions from §11, in order.** Question one first, always:

> Could any of this be **deleted** rather than written?

The most common improvement to a diff is making it smaller.

---

## 3. Project-specific invariants

The ones that break a guarantee rather than a preference. Check every time.

- [ ] Every new Server Action re-verifies session **and** capability independently — not via
      the layout (D-18, FR-44)
- [ ] Every new Server Action has a test proving it rejects insufficient capability
- [ ] `now` is injected in any new domain logic — never `new Date()` inside
- [ ] No new column stores a guest identifier — no name, email, phone, or IP
- [ ] Street addresses absent from any new log, error report, or calendar output
- [ ] Any new route added to the accessibility sweep route list
- [ ] Any new component added to `/styleguide` in every state
- [ ] Contrast validated for any new colour token, **both themes**
- [ ] **If this changes what data is collected, `/privacy` and `/transparency` are updated in
      this same branch** (TRANSPARENCY-PAGES §7)

That last one is the standing rule. A privacy page that silently becomes false is worse than
never having made the promise.

---

## 4. Manual passes — required, not optional

Walk Osha through each. Ask for the actual result; do not accept "probably fine."

**Keyboard.** Physically unplug the mouse. Complete the phase's journeys using only `Tab`,
`Shift+Tab`, `Enter`, `Space`, and arrows.

- Focus always visible?
- Focus order matches visual order?
- Anything reachable but unusable, or usable but unreachable?
- Any focus trap outside a modal?
- Any focused element hidden behind a sticky header? (SC 2.4.11 — the most common miss here)

**VoiceOver, macOS Safari.** `Cmd+F5`. Then iOS Safari.

- Everything announced sensibly?
- Errors announced when they appear?
- Anything announced confusingly, or not at all?

If the phase touched `InheritedFieldIndicator`, give it a dedicated pass — **eyes closed,
someone else driving.** If inherited cannot be distinguished from overridden by ear, it has
failed regardless of what axe says. That is FR-34 and it is the highest-risk component in the
project.

**Zoom and reflow.** 400% zoom, and a 320px viewport. No horizontal scroll, nothing clipped.

**Reduced motion.** Enable the OS setting; confirm animation stops.

**Forced colours** (Phase 6, Windows High Contrast). Confirm nothing disappears.

---

## 5. Record it

Prompt Osha to write both. Do not write these for them.

**`BUILD-LOG.md`** — append an entry using the template. Push for the honest fields:

- What went wrong, and **how long it cost**
- What surprised them
- Manual pass results, verbatim, using the template in that file

A log where everything went smoothly has been edited into uselessness.

**`LEARNINGS.md`** — entries in their own words, from memory, without looking. Format is
*I thought X / actually Y*, because the misconception is the better retrieval key. Anything
they cannot produce without checking goes under **Unresolved** instead — that section is the
most useful part of the document and the agenda for the next session.

---

## 6. Commit and PR

Conventional Commits, including the project's non-standard `a11y` type — it makes the
accessibility work legible in `git log`, which is where a reviewer looks for evidence it was
not an afterthought.

```
feat(occurrence): resolve inherited fields from series defaults
a11y(console): announce inherited state as text, not colour
```

Reference requirement IDs in bodies (`Implements FR-23`) so a requirement traces to a commit
to a test.

**No `Co-Authored-By: Claude` trailer. No "Generated with Claude Code" footer on the PR body.**

PR description: what changed, which FRs it implements, manual pass results, and anything
deliberately deferred.

---

## 7. Then stop

Confirm the phase exit criteria in `BUILD-PLAN.md` are met before moving on. If Phase 1 just
shipped, the plan says to **use the site for a week** before starting Phase 2 — a week of real
use surfaces things no plan predicted. Say so rather than rolling straight into the next
phase.
