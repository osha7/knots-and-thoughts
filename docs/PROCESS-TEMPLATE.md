# Process Template — Reusing This Method

The method abstracted from Knots & Thoughts, for reuse on the next application. Written
with the **photography print store** specifically in mind, with a section on where a
commercial project must diverge.

---

## 1. Read this first if you are building the print store

### Vercel's Hobby tier does not permit commercial use

**This is the single most important thing on this page.** Vercel's Hobby plan is for
personal, non-commercial projects. **Selling photography prints is commercial use.** A
store on Hobby is a terms-of-service violation, and the remedy is a suspended deployment
— possibly mid-order.

Your options:

| Option | Cost | Notes |
|--------|------|-------|
| Vercel Pro | $20/month | Simplest. Same stack, same knowledge, permitted. |
| Cloudflare Pages/Workers | $0–5/month | Commercial use permitted on the free tier. Costs the OpenNext adapter friction we avoided for K&T. |
| Netlify | $0 | Commercial use permitted on the free tier. Verify current terms before committing. |

So the print store is **not** a free project. Budget roughly $20–35/month once you add
Vercel Pro, a domain, and possibly paid image storage. Knowing that now beats discovering
it after building.

### Everything else that changes

| Concern | Knots & Thoughts | Print store |
|---------|-------------------|-------------|
| Guest PII | Zero, by construction | **Unavoidable** — name, shipping address, email |
| Privacy posture | "We collect nothing" | A real policy, GDPR/CCPA obligations, data-deletion requests |
| Payments | None | Stripe. **Never touch card data** — use Stripe Checkout or Elements so you remain PCI SAQ-A |
| Sales tax | None | Stripe Tax. Do not hand-roll nexus rules |
| Images | None | Many large files. **Cloudflare R2, not S3** — R2 has no egress fees, and galleries are almost pure egress |
| Fulfilment | None | Print-on-demand (Prodigi, Printful) or self-fulfil. Decide before designing the order model |
| Legal pages | Privacy, transparency | Plus terms of service, refund policy, shipping policy |
| Auth | Magic link, 4 admins | Customer accounts, or guest checkout. Guest checkout converts better |
| Background work | None | Order confirmation, receipts, fulfilment webhooks — this is where **Docker becomes relevant again** |

**The privacy architecture does not transfer.** K&T's guarantee was "there is no
subscriber table." A store must store customer data. Do not copy the privacy page and
edit it — write a truthful one from scratch. A privacy policy that overstates is worse
than a plain one.

---

## 2. The method, in order

### Step 1 — Answer the architectural questions before writing code

Decisions that are cheap now and expensive later. For K&T this was a genuine
back-and-forth, and it was the highest-value hour of the project.

The checklist:

- [ ] **Hosting and database** — and *verify the terms permit your use case*
- [ ] **Authentication** — separately for each distinct actor type
- [ ] **Data model** — the biggest fork; get this wrong and everything downstream fights you
- [ ] **What data you collect** — decide deliberately; the default is to collect too much
- [ ] **Roles and permissions** — even "just me" is a decision worth recording
- [ ] **What is explicitly out of scope** — write it down or it creeps in
- [ ] **Where money is involved** — cost per month at zero traffic, and at success

For each, write the alternatives you rejected and why. That is what DECISIONS.md is, and
it is what stops you relitigating the same choice in month three.

### Step 2 — Separate the documents by when they are consulted

Nine documents was right for K&T. The split matters more than the count:

- **PRD** — what and for whom. Numbered, testable requirements.
- **DECISIONS** — why. Alternatives rejected. Revisit conditions.
- **ARCHITECTURE** — how. Schema, layers, the core algorithm.
- **Cross-cutting constraints** — one document each for the things that touch everything.
  For K&T: security/privacy, accessibility, observability. For the store, add payments.
- **TEST-PLAN** — how you know it works.
- **BUILD-PLAN** — the executable sequence.
- **BUILD-LOG** — what actually happened. The most valuable one for the *next* project.

### Step 3 — Number your requirements

`FR-23` is referenceable from a test, a commit message, and a pull request. "The thing
about addresses in the calendar" is not. Numbered requirements are what make a test plan
traceable rather than aspirational.

### Step 4 — Identify the two or three genuinely risky pieces

Most of an application is unremarkable. For K&T the real risk was concentrated in
occurrence resolution (DST) and the authorization matrix (privilege escalation). Both got
disproportionate test attention, and both were made **pure functions** so that attention
was cheap to apply.

Ask early: *what here is subtle enough to be wrong for months without anyone noticing?*
Then make that thing pure and test it exhaustively.

For the print store, that list is: money arithmetic (never floats — integer cents),
inventory when two people buy the last print simultaneously, and tax calculation.

### Step 5 — Foundations before features

Phase 0 ships nothing a user can see: repository, CI, accessibility gates, deploy
pipeline, uptime monitoring. It feels like procrastination and it is the opposite.
Retrofitting a CI accessibility gate onto forty existing components is a miserable week.
Adding it to one placeholder component is twenty minutes, and every later component
inherits it.

### Step 6 — Make quality gates mechanical, not cultural

The two devices from K&T that generalise:

1. **A render helper that always asserts accessibility**, so no component test can skip it.
2. **A meta-test that fails when a component has no test file**, so coverage of *existence*
   is enforced rather than remembered.

The principle: **if a rule depends on someone remembering it, it will eventually be
forgotten.** Encode it in a test, a lint rule, or a type. Applies equally to "never log
PII" (enforce in the logger, not at call sites) and "domain layer stays pure" (enforce with
`no-restricted-imports`).

### Step 7 — Domain logic first, in pure functions

Per phase: pure logic and its tests, then repositories, then services, then UI. The
interesting logic ends up testable in milliseconds with no database and no mocks. Mocking
Prisma proves your mocks work; a pure function proves your logic works.

Always inject `now` rather than reading the clock. It is a one-word change that makes every
time-dependent behaviour deterministic.

### Step 8 — Each phase ends deployable

K&T Phase 1 shipped a working site whose content was seeded directly in the database —
useful before any admin console existed. That ordering meant a week of real use informed
Phase 2.

Resist "build all the models, then all the services, then all the UI." Vertical slices
surface the problems horizontal layers hide.

### Step 9 — Log what actually happened

BUILD-LOG.md is the highest-leverage artifact for the *next* project, and the one most
likely to be skipped. Plans describe intent; logs record where reality diverged. That
divergence is exactly what you want to know next time.

---

## 3. What transfers directly

Reusable with little or no change:

- The document set and its structure
- `renderAccessible` helper and the component-coverage meta-test
- The CI workflow shape — five named jobs, accessibility separate so failures are named
- `src/lib/env.ts` Zod validation pattern
- The redacting logger
- The self-hosted `ErrorReport` table, digest cron, and scrubbing
- `/api/health` and the uptime monitor configuration
- Layering rules and the `no-restricted-imports` enforcement
- TypeScript strictness settings
- The accessibility definition-of-done checklist
- The rate limiting table and hashed-IP approach

## 4. What must be rethought

- **Privacy posture** — a store collects PII; write a truthful policy from scratch
- **Payments and PCI scope** — new domain entirely
- **Money handling** — integer cents, never floating point
- **Concurrency** — inventory has races that an event calendar does not
- **Image pipeline** — storage, derivatives, delivery, and cost at scale
- **Background jobs** — order processing wants a worker, which brings Docker back
- **Hosting tier** — commercial use, per §1
- **Legal surface** — terms, refunds, shipping, consumer protection by jurisdiction

---

## 5. Time expectations

For K&T, working evenings and weekends:

| Phase | Estimate |
|-------|----------|
| 0 — Foundations | 8–12 hours |
| 1 — Guest path + privacy pages | 12–16 hours |
| 2 — Admin auth | 6–8 hours |
| 3 — Event editing | 12–16 hours |
| 4 — Roles | 8–10 hours |
| 5 — Calendar feeds | 6–8 hours |
| 6 — Hardening and launch | 8–12 hours |
| **Total** | **60–80 hours** |

Phase 0 looks disproportionate and is not. The accessibility and testing infrastructure
built there is what keeps Phases 1–6 near their estimates.

The print store is meaningfully larger — payments, images, fulfilment, and legal roughly
double it. But Phase 0 should be *faster* the second time, because the templates exist.
That speedup is the entire return on documenting this.

---

## 6. Anti-patterns this process is designed to prevent

| Anti-pattern | The guard |
|--------------|-----------|
| "We'll add accessibility later" | CI gate from Phase 0; a11y in the definition of done |
| "We'll add tests later" | Meta-test fails on any untested component |
| Privacy policy written to sound reassuring | Structural guarantees; public repo; a "what we cannot promise" section |
| Silent scope creep | Explicit non-goals; additions require a decision entry |
| Authorization enforced by hiding buttons | Guard clause in every Server Action; one test per action |
| Wrong times twice a year | Wall-clock + IANA zone; explicit DST test cases |
| A secret in git history | Public repo from day one; `gitleaks` in pre-commit and CI |
| Discovering the site was down from a friend | Uptime monitor, tested by actually breaking it |
| Surprise hosting bill | Verify tier terms in step 1; monthly free-tier check |
| Relitigating settled decisions | DECISIONS.md with alternatives and revisit conditions |
