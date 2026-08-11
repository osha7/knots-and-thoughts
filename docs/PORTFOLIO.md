# Portfolio and Repository Presentation

This project is also a portfolio piece. That imposes requirements the application itself
does not, and one of them resolves a genuine conflict in the design.

---

## 1. The conflict, and the fix

**The site is passphrase-gated. A recruiter or engineer cannot see it.** They will hit a
password field and leave. For a portfolio piece, a live demo nobody can open is close to
having no live demo.

This is not a small thing. Nearly every reviewer follows the same 90-second path: click the
live link, then read the README, then maybe skim the commit history. Code is fourth at
best. Breaking step one wastes the other three.

### The fix: a public demo deployment

`demo.knotsandthoughts.com` — same codebase, separate Neon branch, separate environment
variables, **passphrase printed on the gate itself**.

- [ ] `FR-57` A demo deployment exists with its passphrase displayed on the gate
- [ ] `FR-58` Demo data is unmistakably fictional — invented venues and hosts, no real
      addresses
- [ ] `FR-59` The demo is visually marked as a demo, so nobody mistakes it for the live site
- [ ] `FR-60` Demo seed data includes every interesting state: an inherited week, an
      overridden week, a cancelled week, a hidden address, and venue accessibility notes

That last requirement is what makes the demo *useful*. A demo showing one happy-path event
demonstrates nothing. A demo showing an override, a cancellation, and a
partially-hidden address demonstrates the whole data model at a glance.

Demo credentials in the README too, for anyone who wants the console: a seeded Owner and a
seeded Host, so a reviewer can see the authorization difference for themselves. That is the
single most convincing thing in the project and it's invisible without a way in.

**Keep the demo database separate from production.** Same code, different branch — so a
reviewer poking at the demo can never reach a real address.

---

## 2. The repository README

The most-read file in the project. Not the same document as `docs/README.md` — that indexes
the specification; this one sells the work.

Order matters, because most people stop a third of the way down.

```markdown
# Knots & Thoughts

One sentence: what it is and who it's for.

[ screenshot — the details page, light theme, real-looking content ]

**[Live demo →](https://demo.knotsandthoughts.com)** · passphrase: `xxxx`
**[Design system →](https://demo.knotsandthoughts.com/styleguide)**
**[Privacy →](https://knotsandthoughts.com/privacy)**

## What it does
Three or four bullets. Plain language.

## Why it's built this way
The short version of the four or five decisions worth knowing, each linking
into docs/DECISIONS.md. This is the section that distinguishes the project.

## Accessibility
WCAG 2.2 AA. What's automated, what's manual, and honestly stated: what
automation cannot catch.

## Architecture
[ diagram ]
The layering rule in two sentences.

## Testing
The five CI jobs and what each guards. Coverage numbers.

## Running locally
Actually correct, actually tested from a clean clone.

## Documentation
Link to docs/, with a line on each.
```

### Specifics that matter

**A screenshot above the fold.** Not a logo, not a badge wall — the actual product. And a
short screen recording (a GIF or an MP4) of the override-then-revert flow, because that
behaviour is impossible to convey in a still.

**Link the design system.** `/styleguide` running live is unusual to see in a portfolio
repo, and it reads as systems thinking rather than visual taste.

**Lead the "why" section with the privacy architecture.** "There is no subscriber table,
and that's verifiable" is a more interesting claim than any framework choice, and it invites
the reader into `DECISIONS.md`.

**Keep "Running locally" honest.** Clone into a fresh directory and follow your own
instructions before launch. Broken setup steps are the most common defect in portfolio
repos and the most damning, because they suggest nobody ever checked.

- [ ] `FR-61` README contains a screenshot, live demo link, and demo passphrase
- [ ] `FR-62` README documents the architecture with a diagram
- [ ] `FR-63` Setup instructions verified from a clean clone before launch

---

## 3. Architecture diagram

Needed for the README. Options, in order of preference:

1. **Mermaid in the README** — GitHub renders it natively, it's version-controlled, it
   diffs, and it costs nothing. Start here.
2. **Excalidraw** — hand-drawn feel, exports SVG, free, no account needed.
3. **A screenshot of the layering rule** as ASCII, as in `ARCHITECTURE.md §2` — perfectly
   respectable and already written.

Mermaid is the right default: a diagram that lives in the repo and updates with the code
beats a prettier PNG that goes stale in three weeks.

Show the request path — browser → middleware → Server Component → service → repository →
Postgres — and mark where authorization is enforced. That last annotation is what makes it
an *architecture* diagram rather than a box drawing.

---

## 4. Commit history

People read this. `fix stuff` forty times is worse than no history at all, and it cannot be
retrofitted — so the discipline starts at commit one.

**Conventional Commits**, enforced by a `commit-msg` hook:

```
feat(occurrence): resolve inherited fields from series defaults
fix(calendar): omit street address from ICS LOCATION
test(auth): cover all 56 role/capability pairs
docs(privacy): state Google Calendar feed retention
chore(deps): update prisma to 6.4.0
a11y(console): announce inherited state as text, not colour
```

`a11y` is a non-standard type. Use it anyway — it makes the accessibility work legible in
`git log`, which is exactly where a reviewer looks for evidence that it wasn't an
afterthought.

Reference requirement IDs in bodies (`Implements FR-23`) so a reviewer can trace a
requirement to its commit to its test. That traceability is unusual and noticed.

**One branch per phase, small commits within it.** Squash-merge phases so `main` reads as a
clean narrative, but keep the granular history on the branch.

- [ ] `FR-64` Conventional Commits enforced by a `commit-msg` hook from the first commit

---

## 5. Repository hygiene

**`LICENSE`.** A public repo without one is legally all-rights-reserved, which contradicts
inviting people to read the code. **MIT** unless you have a reason otherwise.

**`CHANGELOG.md`.** Optional, but it pairs with the privacy commitment: it shows when the
policy changed and why. Cheap credibility.

**Dependency automation.** A public repo with six months of stale dependencies is a bad
signal, and you already know the pain from work. **Renovate**, grouped and weekly:

```json
{
  "extends": ["config:recommended"],
  "schedule": ["before 6am on Monday"],
  "packageRules": [
    { "matchUpdateTypes": ["minor", "patch"], "groupName": "minor and patch",
      "automerge": true },
    { "matchUpdateTypes": ["major"], "dependencyDashboardApproval": true }
  ],
  "vulnerabilityAlerts": { "labels": ["security"] }
}
```

Automerging minor and patch is safe **only because CI is comprehensive** — five jobs
including accessibility. That's a real payoff for the Phase 0 investment: the test suite
earns you the right to stop hand-reviewing dependency bumps.

**Badges, sparingly.** CI status and license. Not eleven.

**Issue and PR templates.** The PR template carries the two checkboxes that matter:

- [ ] Manual keyboard and screen-reader pass performed
- [ ] If this changes what data is collected, `/privacy` and `/transparency` updated in this
      PR

- [ ] `FR-65` `LICENSE` present
- [ ] `FR-66` Renovate configured with grouped weekly updates
- [ ] `FR-67` PR template includes the accessibility and privacy checkboxes

---

## 6. What actually distinguishes this project

Being honest about what a reviewer will and won't care about.

**Will land:**

- **The decision records.** 24 decisions with rejected alternatives and revisit conditions.
  Almost no portfolio project has this. It reads as senior.
- **Accessibility at real depth.** Not an `aria-label` sprinkle — WCAG 2.2 AA, a blocking CI
  job, manual screen-reader passes, and a design system with validated contrast. This is a
  genuinely scarce skill and it's visible in the git log.
- **Privacy as architecture.** "There is no subscriber table, and here's the file where you
  can confirm it." Reviewers who care will care a lot.
- **The honesty.** A "what we cannot promise" section on a privacy page is rare enough to be
  memorable. So is documenting *why not* Docker, AWS, and Sentry.
- **Test design.** 100% coverage on a pure domain layer, a 56-case authorization matrix,
  explicit DST cases. Shows you know where risk actually lives.

**Won't land, so don't over-invest:**

- Framework choice. Nobody is impressed by Next.js.
- Line count. Smaller is better.
- Feature count. A well-built small thing beats a sprawling half-built one, and it always
  has.

**The pitch, if someone asks what it is:** *"A private event page for a friends' group. The
interesting parts are that it collects no data about visitors — provably, not as a promise —
and that accessibility is enforced by CI rather than by intention. The decision records
explain why it isn't built the obvious way."*

---

## 7. A talk-track for the interview

You will be asked to go deep on something. These are the four strongest, in order — and
each is strong because it has a *because*.

1. **"Why store wall-clock time instead of a UTC timestamp?"** Because the event is
   "7 PM Central every Wednesday," not an instant. Storing UTC makes it silently drift an
   hour twice a year. There are explicit DST tests for both transitions.

2. **"How does the Host role work?"** Row-level authorization — a Host may edit only weeks
   where they are the assigned host, and specifically *cannot* reassign the host field,
   because that would be a privilege-escalation path. Every Server Action re-verifies
   independently, since a hidden button is presentation rather than protection.

3. **"Why not Sentry?"** Because calendar feed URLs are bearer credentials and Sentry
   captures request URLs — it would have shipped subscribers' access tokens to a third
   party. Error reports stay in our own database, with tokens scrubbed before write.

4. **"How is accessibility enforced?"** Mechanically. A render helper that runs axe on every
   component test, so the assertion can't be skipped, plus a meta-test that fails when a
   component has no test file. And a clear statement that automation catches only 30–40% of
   real barriers, which is why manual passes are logged per phase.

The pattern worth noticing: each answer names a **tradeoff and its cost**, not just a
choice. That's the difference between explaining a decision and reciting one.
