# Knots & Thoughts — Project Documentation

Planning and specification documents for **knotsandthoughts.com**, a passphrase-gated
site that tells a private group of friends where the weekly Wednesday gathering is
being held, with an authenticated admin console for organizers.

**Status:** Pre-implementation. No code written yet. These documents are complete
enough to begin Phase 0 on a fresh machine.

**Author:** Osha G. (github: `osha7`)
**Last updated:** 2026-07-27

---

## How to use these documents

Read in this order the first time:

| # | Document | What it answers |
|---|----------|-----------------|
| 1 | [PRD.md](./PRD.md) | What are we building, for whom, and what is explicitly out of scope |
| 2 | [DECISIONS.md](./DECISIONS.md) | Every technical choice, the alternatives rejected, and why |
| 3 | [ARCHITECTURE.md](./ARCHITECTURE.md) | Stack, layering, database schema, the core algorithms |
| 4 | [ERROR-HANDLING.md](./ERROR-HANDLING.md) | Error taxonomy, Result types, Server Action failures, what users see |
| 5 | [SECURITY-PRIVACY.md](./SECURITY-PRIVACY.md) | Threat model, what we promise, and what we honestly cannot |
| 6 | [TRANSPARENCY-PAGES.md](./TRANSPARENCY-PAGES.md) | The public `/privacy` and `/transparency` pages, with draft copy |
| 7 | [DESIGN.md](./DESIGN.md) | Typography, color tokens with contrast ratios, layout, `/styleguide` |
| 8 | [ACCESSIBILITY.md](./ACCESSIBILITY.md) | WCAG 2.2 AA requirements and how each is verified |
| 9 | [CODE-STANDARDS.md](./CODE-STANDARDS.md) | What "slop" means here; TypeScript, ESLint, comments, test quality |
| 10 | [TEST-PLAN.md](./TEST-PLAN.md) | Unit, integration, e2e, and accessibility test strategy |
| 11 | [OBSERVABILITY.md](./OBSERVABILITY.md) | Uptime, error reporting, backups, and why not Docker or AWS |
| 12 | [BUILD-PLAN.md](./BUILD-PLAN.md) | Phase-by-phase execution steps, starting from a bare laptop |
| 13 | [PROJECT-TRACKING.md](./PROJECT-TRACKING.md) | GitHub Issues and Projects in place of Jira; cadence |
| 14 | [PORTFOLIO.md](./PORTFOLIO.md) | Demo deployment, repo README, commit discipline, interview talk-track |
| 15 | [LAUNCH.md](./LAUNCH.md) | Passphrase selection, telling your friends, add-to-home-screen, GDPR |
| 16 | [PROCESS-TEMPLATE.md](./PROCESS-TEMPLATE.md) | The method abstracted, for reuse on the photography print store |
| 17 | [BUILD-LOG.md](./BUILD-LOG.md) | Running record of what actually happened, session by session |
| 18 | [LEARNINGS.md](./LEARNINGS.md) | What I now understand, organized by concept — and what I don't yet |

**BUILD-LOG vs. LEARNINGS:** the log is chronological and append-only — *what happened, when*.
Learnings is topical and meant to be rewritten — *what I now know*. A log is bad for
retrieval; a topical doc is bad for capturing mistakes and sequence. Keep both.

When you sit down to build, work from **BUILD-PLAN.md** and append to
**BUILD-LOG.md** as you go. The log is what makes the second application faster
than the first — it captures the things that went wrong, which no plan predicts.

---

## Transferring to the build machine

These documents were written on an employer-issued laptop. The project is personal and
should be built on personal hardware.

**Recommended: AirDrop or iCloud the folder, then start git on the personal machine.**

Copy the whole folder — it contains a hidden `.claude/` directory that is easy to lose. Use
AirDrop on the folder itself, or `zip -r` it, rather than selecting the visible files.

```bash
# On the personal machine, with the copied folder at ~/Downloads/knots-and-thoughts
DEST=~/Development/knots-and-thoughts
mkdir -p "$DEST/docs"
cd ~/Downloads/knots-and-thoughts

mv *.md "$DEST/docs/"          # the 17 specification documents
mv .claude "$DEST/"            # hooks, skills, permissions — do not lose this
cd "$DEST"

# CLAUDE.md belongs at the ROOT, not in docs/ — Claude Code loads it from there
mv docs/CLAUDE.md .

chmod +x .claude/hooks/format-and-lint.sh

git init
git add . && git commit -m "docs: add specification for Knots & Thoughts"
gh auth login          # as osha7
gh repo create knots-and-thoughts --public --source=. --remote=origin --push
```

Resulting layout:

```
knots-and-thoughts/
├── CLAUDE.md                 ← root. The continuity mechanism.
├── .claude/
│   ├── settings.json         ← hooks + permissions
│   ├── hooks/
│   └── skills/               ← /new-component, /phase-review
└── docs/                     ← the other 17 documents
```

`jq` is required by the hook: `brew install jq`.

**Why not just `git push` from the work laptop?** Because git history is a durable record of
where work was authored. Starting it on personal hardware means every commit — including the
first — is authored there. That costs nothing and is tidier, which matters more for the
commercial print store that follows.

### Verify the handoff worked

Open Claude Code in the project root and ask:

> *What's our working agreement, and what should I do next?*

If it answers *"you write the code, I teach"* and points at BUILD-PLAN Phase 0.1, `CLAUDE.md`
loaded correctly. If it offers to write the application for you, it didn't — check that
`CLAUDE.md` is at the repository root rather than inside `docs/`.

### A good first message for the new session

> I'm picking up the Knots & Thoughts project. Read `CLAUDE.md` and
> `docs/LEARNINGS.md`, then let's start Phase 0. Before we touch anything, I want to work
> through the Unresolved list — start with Server Components vs. Server Actions, because
> I'm currently just repeating what the docs say.

---

## The one-paragraph version

A friend visits `knotsandthoughts.com`, types a shared passphrase once, and sees
this Wednesday's time, place, and host, plus the next two or three weeks. They can
optionally add an auto-updating calendar subscription. No account, no email, no
name — we collect nothing about guests, and the source is public so that claim is
verifiable rather than merely asserted. Organizers sign in with an email magic link
to a console where four roles (Owner, Editor, Host, Viewer) have distinct powers.
Built with TypeScript, Next.js, Prisma, and Postgres; hosted free on Vercel and
Neon; accessible to WCAG 2.2 AA; covered by unit and end-to-end tests including
automated accessibility checks.

---

## Cost

| Item | Cost |
|------|------|
| Domain `knotsandthoughts.com` | ~$11–15 / year |
| Vercel Hobby hosting | $0 |
| Neon Postgres (free tier) | $0 |
| Resend transactional email (free tier) | $0 |
| GitHub public repository + Actions | $0 |
| **Total** | **~$12 / year** |

The domain is the only recurring cost. Everything else stays free at this scale
and is not a trial that expires.

---

## Important context for whoever builds this

These documents were written on an employer-issued laptop but the project is
personal. Two consequences:

1. **Build it on personal hardware.** Especially relevant for the photography
   print store that follows, which is a commercial venture. Review your employment
   agreement's IP-assignment clause before writing code for that one.
2. **Corporate TLS interception** on the original machine caused a custom CA to be
   installed. If `npm install` or the Vercel CLI produce confusing certificate
   errors on a corporate network, that is the cause — it is not a bug in the
   project. Build on a home network.
