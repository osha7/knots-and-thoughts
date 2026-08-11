# Build Log

Running record of what actually happened — including what went wrong, which is the part
worth having. Append; never rewrite history.

**Why this document matters most:** the plan describes intent. This records where reality
diverged from it. That divergence is precisely what will make the photography print store
faster to build than this one.

---

## How to use this

Append an entry per working session. Record:

- What you set out to do
- What you actually did
- **What went wrong, and how long it cost** — the most valuable field
- Any decision made on the fly, and whether it belongs in DECISIONS.md
- Manual accessibility pass results, verbatim
- Anything that surprised you

Do not tidy it. A log that reads as though everything went smoothly is a log that has been
edited into uselessness.

---

## Manual accessibility pass template

Copy per phase. These results are required by the ACCESSIBILITY §6 definition of done.

```
### Manual accessibility pass — Phase N — [DATE]

**Keyboard only** (mouse physically unplugged)
- Journeys attempted:
- Focus always visible:            yes / no
- Focus order matches visual order: yes / no
- Anything reachable but unusable:
- Anything usable but unreachable:
- Focus traps found:
- Issues:

**VoiceOver / Safari / macOS**
- Journeys attempted:
- Everything announced sensibly:   yes / no
- Confusing or missing announcements:
- Issues:

**VoiceOver / Safari / iOS**
- Issues:

**NVDA / Firefox / Windows** (required by Phase 6)
- Issues:

**Zoom and reflow**
- 400% zoom, no horizontal scroll:  yes / no
- 320px width, nothing clipped:     yes / no

**Reduced motion**
- All animation stops:              yes / no

**Forced colours** (Windows High Contrast)
- Nothing disappears:               yes / no

**Verdict:** pass / pass with follow-ups / fail
**Follow-ups filed:**
```

---

## 2026-07-27 — Planning session

**Set out to do:** Decide the architecture and produce a specification complete enough to
build from on a different machine.

**Did:** Worked through every architectural decision and wrote ten documents. No code.

**Decisions made** (full reasoning in DECISIONS.md):

| Area | Choice |
|------|--------|
| Hosting | Vercel + Neon Postgres |
| ORM | Prisma |
| Router | Next.js App Router, Server Actions |
| Admin auth | Email magic link — Auth.js + Resend |
| Guest access | Shared passphrase, Argon2id, rotatable |
| Data model | Series + occurrence overrides, `null` means inherit |
| Time storage | Wall-clock + IANA zone, never a UTC instant |
| Roles | Owner, Editor, Host, Viewer — explicit capability matrix |
| Calendar | Anonymous per-person tokens, zero stored PII |
| Guest view | Next event plus following 2–3 weeks |
| Docker | Not used |
| AWS | Not used |
| Error reporting | Self-hosted table + Resend digest, not Sentry |
| Transparency | `/privacy` and `/transparency`, public, outside the gate |
| Testing | Vitest + Playwright + axe, accessibility a named blocking CI job |

**Requirements added mid-session**, in the order they came up:

1. Notifications — resolved to calendar subscription only; no email or SMS in v1
2. A hard requirement that guest data is never shared, and that the claim be *true* —
   drove the zero-PII architecture (D-11) and the public repository (D-13)
3. Docker and AWS evaluated and rejected, with reasoning recorded (D-19, D-20)
4. Free but effective error reporting — drove the self-hosted approach (D-21) and, more
   importantly, surfaced that **uptime monitoring matters more than error reporting** for
   a site like this
5. Public security and privacy policy pages explaining the *why*, not just the *what* —
   became TRANSPARENCY-PAGES.md, and moved the pages from Phase 6 into Phase 1
6. Component tests and accessibility baked into CI — drove the two mechanical enforcement
   devices (D-23)

**What went wrong / was harder than expected:**

- The data model needed a worked example before it made sense. The abstract description
  of "series plus overrides" did not land; a concrete four-week timeline did. *Lesson: for
  the print store, explain the order/inventory model with a worked example first.*
- "Completely free" needed interrogation rather than acceptance. SMS cannot be free. AWS
  free tiers expire at 12 months. And — found while writing PROCESS-TEMPLATE.md —
  **Vercel Hobby does not permit commercial use**, which means the print store is not a
  free project. Much better to know now.
- Notifications arrived after the data model was settled. It happened not to invalidate
  anything, but it could have. *Lesson: ask about notifications and integrations in the
  first round of questions.*

**Surprises:**

- The strongest privacy guarantee turned out to be *architectural absence* rather than any
  security control. "There is no subscriber table" is verifiable in a way that "we won't
  share your data" never is. This reframed the whole privacy design.
- Sentry, the obvious error-reporting choice, was wrong here — calendar feed URLs are
  bearer credentials, and Sentry captures request URLs. Would have been a quiet credential
  leak to a third party.
- Making the repository public is doing real work as a *product* feature, not just a
  development choice. It is what converts the privacy claim from assertion to something
  checkable.

**Open items carried into Phase 0:**

- [ ] Buy `knotsandthoughts.com` — not yet owned. WHOIS privacy on.
- [ ] Confirm the timezone for the series. Documents assume `America/Chicago`; verify.
- [ ] Decide the second Owner. PRD §11 lockout mitigation requires a real second person.
- [ ] Confirm the group's real venue mix, to sanity-check the `revealAddressAt` design.
- [ ] Build on personal hardware, not the work laptop.

**Next session:** Phase 0, sections 0.1 through 0.4 — accounts, domain, tooling, repository.

---

## 2026-07-27 (later, same session) — specification completed

**Set out to do:** Close the gaps found by asking "what am I forgetting?", then set up the
boundaries and tooling rules so the build produces clean code.

**Did:** Nine further documents and three revisions. Final count: nineteen documents plus a
root `CLAUDE.md`, `.claude/settings.json`, one hook, and two skills.

**Added:** `DESIGN.md`, `PORTFOLIO.md`, `LAUNCH.md`, `LEARNINGS.md`, `CODE-STANDARDS.md`,
`ERROR-HANDLING.md`, `PROJECT-TRACKING.md`, `OBSERVABILITY.md §8` (backups), plus `CLAUDE.md`
and the `.claude/` tooling.

**Decisions D-24 through D-30:** design in code rather than Figma; a public demo deployment;
soft delete plus encrypted backups; no service worker; dark-first with the palette deferred;
split voice register; craft-specific venue access notes.

**Renamed** from *Artistry & Repose* to **Knots & Thoughts** partway through, and the domain
with it.

**What went wrong, and what it cost:**

- **The Figma plan collapsed twice over.** `whoami` showed the only Figma account is on an
  **employer's enterprise org** — putting personal design assets there risks losing them on a
  job change and hands over a plausible ownership claim. Separately, the MCP won't exist on the
  build machine. Two independent disqualifications for a plan I'd spent time on. *Lesson: check
  which account a tool is authenticated as before designing a workflow around it.*
- **The rename left three things `sed` couldn't fix** — an example weak password
  (`Artistry2026!`), a font rationale built on the old name's meaning, and the `[A&R]` email
  subject prefix. *Lesson: after a rename, grep the old name case-insensitively and read every
  hit, because some references are semantic rather than literal.*
- **I broke the README index** by inserting table rows without removing the ones they replaced —
  two documents listed twice with duplicate numbers. Caught only on a later read. *Lesson:
  re-read a table after editing it.*
- **Requirement numbering nearly drifted.** FRs were appended across six documents. An audit
  found FR-1 to FR-86 with no gaps or duplicates, but nothing was *enforcing* that — it was
  luck. Added a map in `PRD.md §8` showing where each range lives.

**Surprises:**

- **Uptime monitoring matters more than error reporting** for a site like this, and it is
  almost always built last. If Neon has an outage nothing throws — the site is simply dead.
- **Sentry would have leaked subscriber credentials.** Calendar feed URLs are bearer tokens and
  Sentry captures request URLs. The obvious tool was wrong for a reason specific to this
  architecture.
- **Vercel's Hobby tier prohibits commercial use.** Fine here; means the print store is *not* a
  free project. Found in the terms, not the pricing page.
- **The passphrase gate hides the portfolio piece.** A reviewer hits a password field and
  leaves. Fixed with a separate demo deployment — but I'd built the whole plan without noticing
  the conflict.
- **A dark-first palette turned out to be a bigger design lever than the accent colour.** Warm
  paper reads *welcoming*; near-black reads *you're inside something*. The gate is a threshold.
- **Specifying the palette surfaced a live conformance bug** — candidate A's border computes
  ≈1.9:1 against 3:1 required. Left in the document uncorrected on purpose, as an example of
  exactly how dark themes fail.

**Belongs in DECISIONS.md:** yes — recorded as D-24 through D-30.

**Open items carried into Phase 0** (superseding the list above):

- [ ] Buy `knotsandthoughts.com`, WHOIS privacy on
- [ ] **Confirm the series timezone** — six documents assume `America/Chicago`
- [ ] Choose a second Owner
- [ ] `brew install jq` — the format-and-lint hook needs it
- [ ] Verify the GitHub links in `TRANSPARENCY-PAGES.md` once the repo is public
- [ ] Palette stays open by design; decide it at `/styleguide` in Phase 0

**Next session:** on personal hardware. Open `CLAUDE.md`, then the Unresolved section of
`LEARNINGS.md`, and start with Server Components versus Server Actions before any setup.

---

## [DATE] — Phase 0

*(template — replace)*

**Set out to do:**

**Did:**

**What went wrong, and how long it cost:**

**Decisions made on the fly:**

**Belongs in DECISIONS.md:** yes / no

**Surprises:**

**Next session:**
