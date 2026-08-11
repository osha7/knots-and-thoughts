# Project Tracking

No Jira, no Confluence. **GitHub Issues + GitHub Projects**, free and unlimited on a
personal account, living in the same repository as the code.

---

## 1. Why this rather than a Jira substitute

Four things it does that a separate tracker cannot:

**Issues link bidirectionally to code.** `Closes #23` in a commit message closes the issue
and creates a permanent link. Six months on you can trace a requirement → issue → commit →
test. This is the whole point, and it is why an external tracker always drifts.

**Scriptable from the terminal.** `gh issue create`, `gh issue list`, `gh project item-edit`.
No browser context-switch in the middle of a task.

**Automation is built in.** A project workflow moves a card to *In progress* when a linked
PR opens and to *Done* when it merges. The board stays accurate without maintenance — which
is the failure mode of every board ever created.

**It is a portfolio artifact.** Jira is invisible to anyone evaluating you. A public repo
with well-written issues traced to commits and PRs reads as disciplined engineering, at no
extra cost.

---

## 2. Structure

| Jira concept | Here | Detail |
|---|---|---|
| Epic | **Milestone** | One per phase: `Phase 0 — Foundations` … `Phase 6 — Launch` |
| Story | **Issue** | One FR, or a tight cluster of related FRs |
| Sub-task | **Task-list checkboxes** in the issue body | GitHub renders a completion count automatically |
| Board column | Project **Status** field | `Not started` · `In progress` · `Blocked` · `Done` |
| Component | **Label** | `a11y` `security` `privacy` `testing` `design` `docs` `infra` |
| Sprint | — | Deliberately none. See §5. |

`Blocked` is worth having as a fourth column even solo — it distinguishes "not started
because I haven't got there" from "not started because it's waiting on DNS propagation."

---

## 3. Issue template

`.github/ISSUE_TEMPLATE/task.md`:

```markdown
## What
One or two sentences.

## Requirements
Implements FR-10, FR-11, FR-13.

## Sub-tasks
- [ ] Domain logic + unit tests
- [ ] Component + test using `renderAccessible`
- [ ] Added to `/styleguide`
- [ ] Route added to the accessibility sweep list
- [ ] Manual keyboard pass
- [ ] Manual VoiceOver pass

## Done when
Observable, checkable. Not "component works" — "guest sees the next occurrence with the
timezone named, and it renders with JavaScript disabled."

## Notes
Links to the relevant docs section.
```

**Always reference FR numbers.** That's what makes the traceability real rather than
aspirational, and it means a stranger reading the repo can follow a requirement to its test.

**"Done when" must be observable.** An issue closed on "it works" is an issue you will
reopen.

---

## 4. Seeding it from the PRD

There are 74 numbered requirements across seven phases. Creating those issues by hand is
tedious and error-prone; script it.

```bash
gh milestone create "Phase 1 — Guest read path" \
  --description "Passphrase gate, details view, privacy pages. See docs/BUILD-PLAN.md"

gh issue create \
  --title "Guest details view renders next occurrence and upcoming weeks" \
  --milestone "Phase 1 — Guest read path" \
  --label "a11y,testing" \
  --body-file .github/issue-bodies/details-view.md
```

Rough sizing so the board is useful rather than granular to the point of noise:

| Phase | Issues |
|-------|-------:|
| 0 — Foundations | ~12 |
| 1 — Guest read path | ~10 |
| 2 — Admin auth | ~6 |
| 3 — Event editing | ~10 |
| 4 — Roles | ~7 |
| 5 — Calendar feeds | ~7 |
| 6 — Hardening and launch | ~12 |
| **Total** | **~64** |

Aim for issues of two to four hours. Smaller becomes bookkeeping; larger hides the fact
that you are stuck.

---

## 5. Cadence — and why no sprints

**Skip sprints.** They exist to coordinate multiple people and to create shared commitment
boundaries. Solo, on evenings and weekends, they mostly manufacture guilt when life
intervenes, and velocity metrics over a sample size of one are noise.

Use instead:

**A WIP limit of one.** One issue `In progress` at a time. Finish it before starting another.
This is the single most valuable practice here, because the actual risk to a solo side
project is not slow velocity — it is six things half-finished and none shippable.

**The phase as the planning unit.** `BUILD-PLAN.md` estimates hours per phase. Record actuals
in `BUILD-LOG.md` and compare. That comparison teaches you something real about your own
estimating; a burndown chart does not.

**A weekly check-in with yourself.** Ten minutes: what moved, what is stuck, what is stale.
If an issue has sat `In progress` for two weeks, it is either too big — split it — or blocked
and mislabelled.

**Phase exit criteria as the only gate that matters.** `BUILD-PLAN.md` defines them per
phase. Do not start the next phase until they are met, and honor the instruction to *use the
site for a week* after Phase 1.

---

## 6. Automation

Project settings → Workflows. Enable:

- Item added to project → set Status `Not started`
- Linked PR opened → set Status `In progress`
- Issue closed → set Status `Done`
- PR merged → set Status `Done`

That covers essentially all board movement, so the board reflects reality rather than your
discipline about updating it.

Then in commits and PR bodies:

```
feat(occurrence): resolve inherited fields from series defaults

Implements FR-33, FR-34.
Closes #23
```

---

## 7. What replaces Confluence

Nothing needs to. The `docs/` directory *is* the knowledge base, and it is better than
Confluence for this project in three specific ways: it is version-controlled so you can see
what changed and when, it is reviewed in pull requests alongside the code it describes, and
it cannot silently drift out of sync with a repository it does not live in.

The one Confluence capability genuinely lost is rich embedding — diagrams, tables of
contents, page trees. Mermaid in Markdown covers diagrams (GitHub renders it natively), and
`docs/README.md` is the page tree.
