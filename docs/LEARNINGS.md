# Learnings

Topical, not chronological. Reorganize freely as understanding improves — unlike
`BUILD-LOG.md`, this document is meant to be rewritten.

**How this differs from BUILD-LOG.md:** the log records *what happened, when*. This records
*what I now know*. The log is for narrative and mistakes; this is for retrieval.

---

## How to write an entry

Four rules, in order of importance.

1. **Lead with the misconception.** "I thought X; actually Y." The wrong belief is the
   better retrieval key, because it's what you'll re-encounter — and it tells future you
   why the fact was worth writing down.
2. **In your own words, from memory, without looking.** Copying documentation teaches
   nothing; reconstructing an explanation is the entire mechanism. If you can't produce it
   without checking, put it under §Unresolved instead.
3. **Note the trigger.** What were you doing when you hit this? That's how you'll find it
   again.
4. **Date it, and flag what will age.** Framework specifics rot. Concepts don't.

Format:

```
### [Concept]
*[date] — while [what I was doing]*

**I thought:**
**Actually:**
**Why it matters:**
**Source:** [link]
**Confidence:** solid / shaky / parroting
```

That last field is the honest one. "Parroting" means you can say it but not defend it —
which is worth knowing before someone asks in an interview.

---

## Seeded from the planning session — 2026-07-27

These came out of deciding the architecture, before any code.

### Storing time for recurring local events
*2026-07-27 — while choosing the data model*

**I thought:** Store timestamps in UTC. That's the standard advice and it's what I'd
reach for automatically.

**Actually:** UTC is correct for *instants* — "the order was placed at this moment." It is
wrong for *recurring local commitments* — "7 PM Central every Wednesday." Store the
wall-clock time (`19:00`) plus an IANA timezone (`America/Chicago`) and derive the instant
on read.

**Why it matters:** If you store UTC, the event silently shifts an hour twice a year at
daylight saving transitions. Nobody notices in testing because tests usually run in one
season. Then in November everyone shows up at the wrong time. Retrofitting the fix means
migrating every stored row.

The distinction to hold onto: *did this happen at a moment* (UTC) or *does this recur at a
local time* (wall clock + zone).

**Source:** DECISIONS.md D-08; ARCHITECTURE.md §4
**Confidence:** solid

---

### Structural guarantees beat behavioural promises
*2026-07-27 — while designing the privacy model*

**I thought:** A privacy policy is a statement of intent that you then honor.

**Actually:** There are two different kinds of claim, and they aren't equally strong.
"We won't share your data" depends on us continuing to behave, plus everyone who touches
the code later behaving too, and you have no way to check. "There is no table in this
system where your name could be stored" doesn't depend on anyone's intentions and is
verifiable by reading one file.

**Why it matters:** It reframes privacy work from *policy* to *architecture*. And it makes
publishing the source code a product feature rather than a development choice — the public
repo is what converts the claim from assertion to something checkable.

Generalizes well beyond privacy: prefer making a bad state *impossible* over making it
*forbidden*. Same reason we enforce accessibility in a render helper rather than a style
guide.

**Source:** DECISIONS.md D-11, D-13; SECURITY-PRIVACY.md §1
**Confidence:** solid

---

### URLs can be credentials
*2026-07-27 — while choosing an error reporting tool*

**I thought:** Sentry is the obvious answer for error tracking. Send it everything, it's a
dev tool.

**Actually:** Sentry captures request URLs. One of our URLs is
`/api/calendar/{token}.ics`, where the token *is* the credential — anyone holding that URL
can read the feed. So default Sentry configuration would have copied every subscriber's
access token into a third party's database.

**Why it matters:** Two lessons, and the second is bigger. First: a capability URL (a link
that grants access by being known) is a secret, and must be treated like one everywhere —
logs, error reports, analytics, referrer headers. Second: **the conventional tool choice
can be wrong for reasons specific to your architecture.** "Everyone uses Sentry" isn't an
argument. Ask what a tool actually collects.

**Source:** DECISIONS.md D-21; OBSERVABILITY.md §4
**Confidence:** solid

---

### Free tiers have shapes, and the shape matters more than the number
*2026-07-27 — while choosing hosting*

**I thought:** "Free tier" is roughly one thing; compare the limits.

**Actually:** They fail in categorically different ways.

- **Supabase** pauses projects after 7 days idle — a low-traffic site's exact failure mode.
- **AWS** free tiers mostly expire at 12 months, then bill. A landmine on a timer.
- **Neon** suspends when idle but resumes in ~1s. Degradation, not failure.
- **Vercel Hobby** prohibits *commercial use* — a legal limit, not a technical one, and
  invisible in any feature comparison.

**Why it matters:** The Vercel one is the sharpest. The print store is commercial, so it
needs Pro at ~$20/month. That's not discoverable by reading a limits table; it's in the
terms. **Read the acceptable use policy, not just the pricing page.**

**Source:** DECISIONS.md D-03; PROCESS-TEMPLATE.md §1
**Confidence:** solid

---

### Uptime monitoring and error reporting solve different problems
*2026-07-27 — while planning observability*

**I thought:** Error reporting is how you find out something's broken.

**Actually:** Error reporting only catches failures that *throw inside your running code*.
If the database is unreachable, or a deploy broke the homepage, or DNS is misconfigured —
nothing throws anywhere you'd see. The site is simply dead, and you learn about it from a
friend.

**Why it matters:** Uptime monitoring is the higher-value investment and it's almost always
built last. It's also nearly free: a health endpoint that does a real query, and a monitor
that checks it.

Corollaries worth keeping: the health check must verify a real dependency (200 because Node
is running proves nothing), it must send `no-store` (or a CDN caches the 200 while you're
down), and **you must test the alarm by actually breaking the site.** An untested monitor is
decoration.

**Source:** OBSERVABILITY.md §2–3
**Confidence:** solid

---

### Abstract explanations of data models don't land; worked examples do
*2026-07-27 — while trying to understand series-plus-overrides*

**I thought:** I'd understand the model from a description of the tables.

**Actually:** "A series row holds defaults, occurrence rows hold exceptions, null means
inherit" didn't click. A concrete four-week timeline — *this* week inherits everything, *this*
one overrides the venue, *this* one is cancelled, *this* one only changes the time — made it
obvious in about ten seconds.

**Why it matters:** This is a *process* learning, not a technical one, and it generalizes:
when a data model isn't landing, ask for the worked example rather than a better
abstraction. Apply it to the print store's order and inventory model, which will be harder
than this one.

**Confidence:** solid

---

## Unresolved — bring these to the next session

Honest list of things not yet understood. **This is the most useful section in the
document.** Add freely; that's the point.

- **Server Components vs. Server Actions** — I know Server Components render on the server
  and Server Actions handle mutations, but I couldn't currently explain when a component
  needs `"use client"` versus not, or what actually crosses the network boundary.
  *Confidence: parroting.*
- **Why Server Actions are "public endpoints"** — I've written down that each one must
  re-verify authorization independently, and I believe it, but I can't yet explain the
  mechanism that makes them callable directly. Want to see this demonstrated.
  *Confidence: parroting.*
- **Argon2id parameters** — `memoryCost 19456, timeCost 2, parallelism 1` came from an
  OWASP baseline. I don't know what tradeoff each dial controls or how I'd choose them for
  different hardware.
- **What a Neon "branch" actually is** — copy-on-write of the storage layer? A full copy?
  Matters for whether CI branches are cheap enough to create per run.
- **Why `noUncheckedIndexedAccess` is the strictness flag people disable** — I've turned it
  on because the plan says so. Haven't yet felt the friction that makes people turn it off.
- **Whether the `revealAddressAt` boundary should be inclusive** — the spec says inclusive
  and there's a test for it, but I picked that arbitrarily rather than for a reason.

---

## Write-up candidates

Turning an entry into 600–900 words of prose is a much harsher test of understanding than
nodding along — and these are interesting to other engineers, which makes them portfolio
artifacts rather than homework.

Ranked by a combination of "how much writing it would teach me" and "how few people can
speak to it."

| Topic | Why it's worth writing |
|-------|------------------------|
| **Why UTC is the wrong default for recurring local events** | Genuinely useful, widely gotten wrong, and has a crisp demonstration (the two November Wednesdays) |
| **Making accessibility non-optional in CI** | Very few engineers can speak to this depth. Strongest differentiator. |
| **Row-level authorization, and why Host can't reassign host** | Shows security thinking — the escalation path is subtle and the fix is one line |
| **When your error tracker leaks credentials** | Contrarian, specific, and a real finding rather than a tutorial |

Do these *after* the relevant phase ships, while it's fresh, not at the end.

---

## Review rhythm

- **End of each session:** add entries. Five minutes.
- **End of each phase:** reread the whole document. Move anything from §Unresolved that you
  now understand — and rewrite the entry from memory rather than editing what's there.
  Re-deriving is the practice.
- **Before any interview:** read §Write-up candidates and PORTFOLIO.md §7 together. Anything
  still marked *parroting* is a question you can't yet survive.
