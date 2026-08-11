# Design System

Code-first. No Figma — see D-24. `DESIGN.md` is the specification; `/styleguide` is the
living implementation.

**Dark-first.** Light is the alternate theme, not the default. See §1.

---

## 1. Direction

**Private, modern, quietly exclusive.** You typed a passphrase to get here, and the interface
should acknowledge that. Deep ink, restrained color, sharp type, generous space. A members'
room after hours — not a craft blog.

### Why dark is the default

This is the single largest lever in the design, larger than which accent gets chosen.

Warm cream paper reads *welcoming*, which is the opposite of the intent. A passphrase gate
opening onto near-black reads **you are inside something now.** The gate is the threshold and
the palette should mark it.

Light remains available and correct for anyone whose OS asks for it — forcing dark on someone
who has set a light preference is hostile, and often an accessibility problem for people with
astigmatism, for whom light-on-dark text can smear. But dark is the design's home.

### Explicitly not

The earlier direction — warm paper, natural dyes, botanical accents — is **rejected**. Madder
and indigo on cream reads folk-craft and hippy. The craft is fiber; the interface need not be.

Three principles, in priority order when they conflict:

1. **Legible before atmospheric.** Somebody is reading an address on a phone, outdoors, in a
   hurry. Every mood choice yields to that. Dark themes fail contrast more often than light
   ones, so this principle does real work here.
2. **Few colors, used hard.** Restraint reads as confidence. One accent, one focus color, one
   danger color. No gradients, no glows, no shadows except a single raised card.
3. **Accessible by construction.** Not a constraint on the aesthetic — near-black with
   high-contrast type is *both* more legible and more modern than the low-contrast grey-on-grey
   that dark themes usually ship.

---

## 2. Typography

Two families, both open-source, both **self-hosted** via `@fontsource-variable` — no font CDN
(D-16), which keeps the CSP tight and removes a render-blocking third-party request.

| Role | Family | Why |
|------|--------|-----|
| Display | **Fraunces** (variable) | A serif with character. Against near-black it reads editorial and a little louche rather than crafty — the `SOFT` and `WONK` axes give it warmth the palette deliberately withholds. |
| Body & UI | **Inter** (variable) | Large x-height, excellent at small sizes. The correct boring choice for anything read quickly. |
| Numeric | Inter, `font-variant-numeric: tabular-nums` | Times align down the schedule list. |

**On dark backgrounds, reduce weight slightly.** Light text on dark appears heavier than the
same weight dark-on-light — an optical effect, not a rendering bug. Body text that wants 400
on paper often wants 350 on ink. Fraunces and Inter are both variable, so this is a token, not
a different font file.

If Fraunces reads as too much once real content is in it, **Newsreader** is the quieter
substitute. Decide with content on screen, not from a specimen.

### Scale

Modular, 1.25 ratio, in `rem` so it honors the user's browser font size. Never `px` for type.

| Token | Size | Line height | Use |
|-------|------|-------------|-----|
| `--text-xs` | 0.8rem | 1.5 | Metadata, "last updated" |
| `--text-sm` | 0.9rem | 1.5 | Helper text, labels |
| `--text-base` | 1rem | 1.6 | Body — never smaller |
| `--text-lg` | 1.25rem | 1.5 | Lead paragraphs, venue name |
| `--text-xl` | 1.563rem | 1.3 | `h2`, upcoming-week headings |
| `--text-2xl` | 1.953rem | 1.2 | The time |
| `--text-3xl` | 2.441rem | 1.1 | `h1`, the date |

- **Body text never below 1rem.** Not for helper text, not for footnotes.
- Prose capped at **66ch**. `/transparency` is long; unbounded measure makes it unreadable.
- Line height ≥1.5 for body.
- Headings in Fraunces; everything else Inter.
- `font-display: swap`, both families preloaded.

---

## 3. Color — three candidates, decided in the browser

The palette is **deliberately undecided.** Choosing an accent from hex codes in a terminal is
guesswork; three candidate token sets get built and the decision happens at `/styleguide` with
real content on screen (D-28).

### Sequencing — this matters

**Build the three dark candidates first. Choose one. Then derive its light counterpart.**

Three candidates × two themes = six token sets to contrast-validate. Picking the dark palette
first halves that work, and dark is the default so it is the right thing to judge on.

### Candidate A — Ink & brass

Near-black with a blue undertone, warm brass accent. Speakeasy. Warm metal against cool
near-black; the most distinctive option and the least likely to look like a dev tool.

| Token | Value | Ratio on surface |
|-------|-------|-----------------|
| `--surface` | `#12141A` | — |
| `--surface-raised` | `#1B1E26` | — |
| `--surface-sunken` | `#0C0E13` | — |
| `--ink` | `#EDEAE3` | **15.3:1** ✓ |
| `--ink-muted` | `#9A9689` | **6.2:1** ✓ |
| `--accent` | `#D9A94E` | **8.5:1** ✓ |
| `--accent-ink` | `#12141A` | 8.5:1 on accent ✓ |
| `--border` | `#2E323C` | ~1.9:1 — **fails 1.4.11, must be lightened** |
| `--focus` | `#7FC4DE` | to compute |
| `--danger` | `#E8837A` | to compute |

### Candidate B — Obsidian & ice

Coolest and most modern. Slate near-black, pale cyan accent. Private in a cryptographic sense
rather than a social one. Risk: closest of the three to reading as a developer tool.

| Token | Value | Ratio on surface |
|-------|-------|-----------------|
| `--surface` | `#0F1319` | — |
| `--surface-raised` | `#171C24` | — |
| `--ink` | `#E8ECF1` | to compute |
| `--ink-muted` | `#8D97A6` | to compute |
| `--accent` | `#7ED0E8` | **10.7:1** ✓ |
| `--accent-ink` | `#0F1319` | 10.7:1 on accent ✓ |
| `--focus` | `#E0A24A` | to compute |

### Candidate C — Deep indigo & bone

Keeps indigo but pushes it cool and dark until it stops reading folk-craft: indigo becomes the
*surface*, bone becomes the active color. Monochrome, gallery-modern, very few colors used
hard.

| Token | Value | Ratio on surface |
|-------|-------|-----------------|
| `--surface` | `#141826` | — |
| `--surface-raised` | `#1E2334` | — |
| `--ink` | `#F0EEE8` | **15.2:1** ✓ |
| `--ink-muted` | `#969AAB` | to compute |
| `--accent` | `#F0EEE8` | 15.2:1 — inverted buttons |
| `--focus` | `#D98C4A` | to compute |

### The `--border` finding, and why it is here

Candidate A's `--border` at `#2E323C` computes roughly **1.9:1** against its surface. **SC
1.4.11 requires 3:1** for component boundaries. It fails.

This is left in the document deliberately rather than quietly corrected, because it is the
exact failure mode dark themes have: a border that looks fine to the eye and is legally
insufficient. **Every candidate's border and focus values must be computed and lifted before
the palette is judged** — otherwise you choose between three palettes on aesthetics and
inherit a conformance bug.

### Rules, regardless of which wins

- **Never the only carrier of meaning** (SC 1.4.1). Cancelled state is the word *Cancelled*.
  Overridden state is a text badge. Color reinforces; it never informs alone.
- **`--focus` is never `--accent`.** If focus and links share a color, a focused link is
  indistinguishable from an unfocused one.
- **Follow `prefers-color-scheme`.** Dark is the default; light applies when asked for.
- **No manual theme toggle** — it needs persistence, a flash-of-wrong-theme fix, and its own
  accessible control, for a preference the OS already knows.
- Semantic tokens only. Components reference intent (`bg-surface-raised`), never a hex. That
  is what makes swapping candidates a one-file change.

---

## 4. Space, shape, motion

4px base, `--space-1` (0.25rem) through `--space-16` (4rem). Vertical rhythm in multiples of
`--space-2`.

| Property | Value |
|----------|-------|
| Radius | `--radius-sm` 4px, `--radius-md` 8px. Nothing rounder — pills read consumer-app. |
| Elevation | Borders, not shadows. One exception: `--shadow-raised` on the next-event card. On dark, elevation is better expressed by a *lighter surface* than by a shadow — shadows barely read against near-black. |
| Max width | 42rem prose, 60rem console |
| Touch target | **44×44 minimum** — clears SC 2.5.8's 24×24 comfortably |
| Focus ring | 2px solid `--focus`, 2px offset, plus `scroll-margin-top` equal to header height (SC 2.4.11) |

```css
@media (prefers-reduced-motion: no-preference) {
  /* every transition lives inside this block, without exception */
}
```

150ms for state, 250ms for entrance. Nothing longer, nothing looping, no parallax, no
scroll-triggered reveals. A site read in thirty seconds should not make anyone wait.

---

## 5. Voice

**Split register, deliberately** (D-29).

### Behind the gate — spare and knowing

Few words. No exclamation marks. Mildly conspiratorial. Confident rather than chatty.

| Instead of | Write |
|-----------|-------|
| "Enter the passphrase to see this week's gathering." | "Enter the passphrase." |
| "Welcome back! Here are the details for this week's event." | *(nothing — just show them)* |
| "Oops! That passphrase didn't work." | "That's not it." |
| "Add to your calendar to stay up to date!" | "Add to your calendar" |

**Tagline, under the wordmark on the gate:** *Bring whatever you're working on.*

That line does real work. It is the one place the site says *all crafts, no gatekeeping* —
which matters, because a name with "Knots" in it could read as knitting-only to someone who
crochets or embroiders or whittles.

### Public pages — plain and precise

`/privacy` and `/transparency` are indexed (FR-52) and are what a portfolio reviewer reads.
Keep them **plain**, not spare.

**An important distinction:** "spare" behind the gate means unfussy. On the public pages it
must never mean terse-at-the-cost-of-clarity. Plain language there is an accessibility
requirement, not a stylistic choice — it serves people with cognitive disabilities, non-native
readers, and anyone skimming on a phone. The existing draft copy in `TRANSPARENCY-PAGES.md` is
already in the right register; do not tighten it into cleverness.

### Craft-agnostic, everywhere

**Never name a specific craft** in any label, placeholder, example, or error message. Not
"knitting," not "your knitting." Write "whatever you're working on," or "your project."

All crafts welcome is the premise. The interface should not quietly center one.

- [ ] `FR-83` No copy anywhere names a specific craft
- [ ] `FR-84` The gate carries the tagline "Bring whatever you're working on."

---

## 6. Key screens

### Passphrase gate

Single centered column, max 26rem, on `--surface`. Order: wordmark in Fraunces, the tagline,
the field, the button, then the privacy and transparency links.

Those links sit **above the fold and before the field** — someone should be able to read the
policy before deciding to type (D-22, FR-47).

No imagery. Loads instantly on bad cellular, nothing to misread.

```
        Knots & Thoughts            Fraunces, --text-2xl
    Bring whatever you're
       working on.                  --text-base, --ink-muted

    Passphrase
    ┌──────────────────────┐
    │                      │        --surface-sunken, --border
    └──────────────────────┘
    [      Continue      ]          --accent

    Privacy · How this works        --text-sm
```

### Details page

```
┌─────────────────────────────────┐
│ Knots & Thoughts                │  Fraunces, --text-xl
├─────────────────────────────────┤
│                                 │
│  THIS WEDNESDAY                 │  --text-sm, --ink-muted, tracked
│  August 12                      │  --text-3xl, Fraunces
│  7:00 PM Central                │  --text-2xl, tabular-nums
│                                 │
│  Wren's studio                  │  --text-lg
│  412 Oak Street                 │  --text-base
│  Hosted by Wren                 │  --text-base, --ink-muted
│                                 │
│  Bright, dining chairs, big     │  --text-sm, in --surface-sunken
│  table. Step-free side door.    │  panel — see ACCESSIBILITY §4
│  One cat.                       │
│                                 │
│  [ Add to your calendar ]       │
└─────────────────────────────────┘

  COMING UP                          --text-sm, --ink-muted
  Aug 19 · 7:00 PM · Ida's           --text-base
  Aug 26 · Cancelled                 --danger, plus the word
```

The date is the largest element. That is the question people came to answer.

The access panel is visually distinct rather than buried in body copy — it is load-bearing
information for some guests, not a footnote.

### Console

Same tokens, denser spacing. Occurrences as cards in a `<ul>`, never a table, so reflow is
free (SC 1.4.10). Inherited fields on `--surface-sunken` with a text badge; overridden fields
on `--surface-raised` with an "Overridden" badge and a revert button.

**The badge text is the mechanism. The surface tint is decoration.** Reverse that and FR-34
fails.

---

## 7. `/styleguide`

A route rendering every component in every state from the real tokens. Four jobs:

1. **The place the palette gets chosen.** A dev-only switcher cycles candidates A, B, and C
   against real content. This is the deliverable that makes D-28 work.
2. **Portfolio artifact** — running code, better than a static mockup.
3. **Accessibility surface** — the axe sweep hits every component state in one pass.
4. **Visual regression target** — Playwright screenshots catch unintended drift.

Contents: the type scale rendered; every token with its **computed** contrast ratio printed
beside it, pass/fail marked; the spacing scale; every component in default, hover, focus,
error, loading, empty, and disabled states.

**The candidate switcher is development-only.** Production ships one palette plus
`prefers-color-scheme`. Do not let it become a user-facing theme picker.

- [ ] `FR-53` `/styleguide` renders every component in every state
- [ ] `FR-54` Each token displays its computed contrast ratio and pass/fail
- [ ] `FR-55` The accessibility sweep covers `/styleguide` in both themes
- [ ] `FR-56` `/styleguide` is reachable without the passphrase
- [ ] `FR-85` A dev-only switcher renders all three candidate palettes against real content

---

## 8. Implementation

Tailwind, configured so tokens are the only route to a value:

```js
// tailwind.config.ts — theme.extend
colors: {
  surface: 'var(--surface)',
  'surface-raised': 'var(--surface-raised)',
  'surface-sunken': 'var(--surface-sunken)',
  ink: 'var(--ink)',
  'ink-muted': 'var(--ink-muted)',
  accent: 'var(--accent)',
  'accent-ink': 'var(--accent-ink)',
  border: 'var(--border)',
  focus: 'var(--focus)',
  danger: 'var(--danger)',
}
```

Then **disable Tailwind's default palette entirely.** If `text-slate-500` still resolves,
someone will use it, and swapping candidates will break in one place nobody notices for a
month. Removing the escape hatch is the point.

Tokens live in `app/globals.css`. Dark under `:root`; light under
`@media (prefers-color-scheme: light)` — note the inversion from the usual arrangement,
because dark is the default.

### Contrast validation in CI

A unit test, not a manual check. **This is what makes the `--border` finding in §3 impossible
to ship.**

```ts
// src/design/contrast.test.ts
const PAIRS = [
  { fg: '--ink',        bg: '--surface',        min: 4.5 },
  { fg: '--ink-muted',  bg: '--surface',        min: 4.5 },
  { fg: '--accent',     bg: '--surface',        min: 4.5 },
  { fg: '--accent-ink', bg: '--accent',         min: 4.5 },
  { fg: '--border',     bg: '--surface',        min: 3.0 },  // SC 1.4.11
  { fg: '--border',     bg: '--surface-raised', min: 3.0 },
  { fg: '--focus',      bg: '--surface',        min: 3.0 },
  { fg: '--danger',     bg: '--surface',        min: 4.5 },
];
```

Parse the CSS, compute, assert the minimum — **for every candidate and for both themes.** Run
it before judging the palettes, so the choice is made among three conformant options rather
than three pretty ones.
