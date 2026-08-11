# Accessibility

**Target: WCAG 2.2 Level AA**, verified by automated checks in CI plus manual
keyboard and screen-reader passes at every phase.

Accessibility was named a core requirement, so it appears here as concrete criteria with
verification methods rather than as an aspiration.

---

## 1. Two things worth establishing first

**Automated testing catches roughly 30–40% of real accessibility problems.** `axe-core`
reliably finds missing labels, insufficient contrast, and broken ARIA. It cannot tell you
that your focus order is illogical, that your error message is unhelpful, or that your
"inherited vs. overridden" indicator is incomprehensible without sight. Automated checks
are a floor that prevents regressions, not evidence of an accessible product. Manual
passes are mandatory per phase and recorded in BUILD-LOG.md.

**The most consequential accessibility decisions here are architectural, not cosmetic.**
Server-rendered HTML that works without JavaScript (NFR-3), semantic markup instead of a
component library's div soup, and magic-link authentication instead of passwords each do
more for real users than any amount of ARIA applied afterward.

---

## 2. WCAG 2.2 criteria that actually bite on this project

Not the full 56-criterion checklist — the ones where this application has genuine
decisions to make.

### 3.3.8 Accessible Authentication (Minimum) — AA

The criterion prohibits requiring a cognitive function test (remembering a password,
solving a puzzle) unless a mechanism is available to assist.

- **Admin sign-in** avoids the cognitive function test entirely. Magic links require
  remembering nothing. This is a substantial part of why D-05 chose them.
- **The guest passphrase** *is* a cognitive function test. It is compliant because
  password-manager support is the permitted assisting mechanism — which means:
  - **Paste must work.** Never `onpaste="return false"`, never any handler that blocks
    it. Blocking paste is the single most common way sites fail this criterion.
  - `autocomplete="current-password"` so managers recognise and fill the field.
  - A real `<input type="password">` with a proper `<label>`, not a custom widget.
  - A "show passphrase" toggle, which is a genuine aid for anyone typing a long phrase
    on a phone. The toggle is a `<button>` with `aria-pressed`, not a checkbox styled
    as an eye.
- **No CAPTCHA anywhere.** CAPTCHAs are a cognitive function test with no assisting
  mechanism. Rate limiting achieves the same protection without excluding people.

### 2.5.8 Target Size (Minimum) — AA

Every interactive target at least 24×24 CSS pixels, including spacing. Our design uses
44×44 as the working minimum, which is the more comfortable iOS guideline and clears the
requirement comfortably. Inline text links are exempt, but the "revert to default"
controls in the console are buttons, not links, and must meet the size.

### 2.4.11 Focus Not Obscured (Minimum) — AA

When an element receives focus it must not be entirely hidden by author content. The
realistic risk here is a sticky header in the admin console covering a focused field
during keyboard navigation. Mitigation: `scroll-margin-top` on focusable elements equal
to the header height. This is easy to break and easy to miss — it goes in the manual
keyboard pass.

### 3.3.7 Redundant Entry — A

Do not ask for the same information twice in one process. Relevant to the organizer
invite flow: after entering an email to invite someone, subsequent steps must not ask
for it again.

### 3.2.6 Consistent Help — A

The link to the privacy page and any help affordance appear in the same relative
position on every page.

### 1.4.3 Contrast (Minimum) and 1.4.11 Non-text Contrast — AA

4.5:1 for body text, 3:1 for large text, 3:1 for UI component boundaries and focus
indicators. Validated in CI. Both light and dark themes are checked — dark themes fail
contrast more often than light ones, usually because a mid-grey secondary text colour
survives on white and dies on near-black.

### 1.4.1 Use of Color — A

**The load-bearing case for this app:** the console must show whether each field is
inherited from the series or explicitly overridden (FR-33). It is tempting to render
overridden fields in a different colour and stop there. That fails.

The state must carry a text or icon indicator with an accessible name — e.g. a badge
reading "Overridden" next to the field, or `aria-describedby` pointing at "Inherited from
series default." Colour may reinforce; it may not be the only carrier. This is FR-34, and
it exists as a numbered requirement precisely because it is the easiest thing here to get
wrong.

### 1.4.10 Reflow — AA

Usable at 320 CSS pixels wide and at 400% zoom without two-dimensional scrolling. The
console's schedule list is the risk — a wide table. It reflows to stacked cards below the
breakpoint rather than scrolling horizontally.

### 2.2.1 Timing Adjustable — A

The 15-minute magic link expiry is an exception permitted for security ("Essential
Exception"), but the email must state the window so nobody is surprised by a dead link.
The 30-day guest session and 7-day admin session are long enough not to engage this
criterion.

---

## 3. Component requirements

### Passphrase gate

```html
<main id="main">
  <h1>Knots &amp; Thoughts</h1>
  <p>Bring whatever you're working on.</p>

  <form method="post" action="?/verify">
    <label for="passphrase">Passphrase</label>
    <input id="passphrase" name="passphrase" type="password"
           autocomplete="current-password" required
           aria-describedby="passphrase-help passphrase-error"
           aria-invalid="true">           <!-- only when errored -->
    <p id="passphrase-help">Ask in the group chat if you don't have it.</p>
    <p id="passphrase-error" role="alert">That's not it.</p>
    <button type="submit">Continue</button>
  </form>
</main>
```

- Native `<form>` with a Server Action, so it works without JavaScript.
- Error is `role="alert"` **and** referenced by `aria-describedby`. The live region
  announces it; the association means a screen reader re-reading the field also finds it.
- `aria-invalid` and the error element appear only in the error state. A permanently
  present empty error container is announced as nothing and helps no one.
- On error, focus returns to the field with its value preserved.

### Event details

```html
<article aria-labelledby="next-heading">
  <h2 id="next-heading">This Wednesday</h2>
  <p><time datetime="2026-08-12T19:00:00-05:00">Wednesday, August 12 at 7:00 PM Central</time></p>
  <p>Wren's studio</p>
  <p>Hosted by Wren</p>
  <p>Bright, dining chairs, big table. Step-free side door. One cat.</p>
</article>
```

- `<time datetime>` gives a machine-readable value alongside human text.
- The timezone is written out (D-09). Never a bare "7:00 PM."
- Cancelled state is conveyed in text — "Cancelled this week" as a heading — never by
  strikethrough alone, which many screen readers do not announce.
- The upcoming weeks are a `<ul>`, because they are a list. Screen readers announce item
  counts, which is genuinely useful.

### Admin schedule list

- Each week is a `<li>` containing a card, not a table row, so reflow is free.
- Read-only weeks (for a Host viewing weeks they do not host) are not merely
  non-interactive — they carry a visible, screen-reader-available reason: "Only the host
  of this week can edit it." Silently disabled controls are hostile.
- Never `disabled` on a focusable control the user might need to understand. Prefer
  rendering static text with an explanation over a `disabled` button that cannot receive
  focus and explains nothing.

### Forms generally

- Every input has a persistently visible `<label>`. No placeholder-as-label — it vanishes
  on input, fails contrast, and defeats autofill.
- Errors are summarised at the top of the form in a `role="alert"` region *and*
  associated per-field via `aria-describedby`. Focus moves to the summary on failure.
- Success confirmations announce through a polite live region, not a toast that
  disappears before a screen reader reaches it.
- Required fields marked in text, not with a bare asterisk.

### Global

- Skip link to `#main` as the first focusable element.
- One `<h1>` per page; no skipped heading levels.
- `<html lang="en">`.
- Unique, descriptive `<title>` per page.
- Visible focus indicator with ≥3:1 contrast against adjacent colours. Never
  `outline: none` without a replacement.
- All animation wrapped in `@media (prefers-reduced-motion: no-preference)`.
- Self-hosted fonts with `font-display: swap`; no third-party font CDN (D-16).

---

## 4. Accessibility of the gathering itself

This is the part most sites forget, and for this application it may matter more than
anything above.

An accessible website that sends a wheelchair user to a third-floor walk-up has not
helped them. The `Venue.accessNotes` field (ARCHITECTURE §3) exists so organizers can
record and guests can read:

### The generic checklist is not the right checklist

Standard venue-accessibility guidance — step-free entry, parking, restrooms — matters, but it
is not what determines whether someone can take part in *this*. People sit for two or three
hours doing close handwork. The access requirements follow from that, and most published
checklists miss them entirely.

**In rough priority order:**

| What | Why it matters |
|------|----------------|
| **Light** | The top one, and the least often mentioned. Good task lighting is what lets a low-vision person do fine stitching at all — and what lets everyone see their work. "Bright, or bring a clip lamp" is more useful than knowing there are no stairs. |
| **Seating with back support** | Three hours on a backless stool or a soft sofa is painful for anyone and impossible with a back, hip, or pelvic condition. "Dining chairs" versus "low couches" is real information. |
| **Table or surface space** | Needed for spreading patterns, cutting, and by anyone who cannot hold work in their lap — including people with hand tremor or limited grip. |
| **Noise level** | A hard-surfaced room with fifteen people talking is genuinely inaccessible to a hard-of-hearing guest, and draining for anyone with sensory sensitivity. Nobody thinks to mention it. |
| **Pets** | Allergies. And a cat plus a ball of yarn is its own hazard. |
| **Step-free entry, or the number of steps** | The conventional one, still needed. |
| **Restroom access** | Especially over a three-hour sit. |
| **Parking, and distance from it** | Distance matters when carrying a project bag. |
| **Scent** | Candles, incense, and strong cooking smells are a barrier for people with migraine or asthma. |

Good notes read like: *"Bright overhead plus two lamps. Dining chairs, big table. Step-free side
door. One cat. Street parking on Oak."* Nine seconds to write, and it tells five different
people whether they can come.

The console prompts for these when creating a venue rather than hiding them in an "advanced"
section, because a field nobody sees is a field nobody fills in. The guest view displays them
whenever present (FR-17), in a visually distinct panel rather than buried in body copy.

- [ ] `FR-86` The venue form prompts explicitly for light, seating, surface, noise, and pets —
      not a single freeform "accessibility notes" box with no guidance

This costs one text field and some placeholder copy, and it changes who can actually attend.

---

## 5. Verification

### Automated, in CI — blocking

| Layer | Tool | Scope |
|-------|------|-------|
| Component | `vitest-axe` | Every component test asserts zero violations |
| Page | `@axe-core/playwright` | Every route, both themes, authenticated and not |
| Contrast | axe colour-contrast rules | Both themes |
| Markup | `eslint-plugin-jsx-a11y` | `strict` preset, warnings treated as errors |

CI fails on any violation. Not a report someone reads later — a red build.

### Manual, per phase — recorded in BUILD-LOG.md

**Keyboard pass.** Unplug the mouse. Complete every journey in PRD §7 using only
`Tab`, `Shift+Tab`, `Enter`, `Space`, and arrow keys. Confirm: focus is always visible,
focus order matches visual order, nothing is reachable but unusable, nothing is usable
but unreachable, and no focus trap exists outside a modal.

**Screen reader matrix.** At minimum the first two:

| Reader | Browser | Platform |
|--------|---------|----------|
| VoiceOver | Safari | macOS |
| VoiceOver | Safari | iOS |
| NVDA | Firefox | Windows |
| TalkBack | Chrome | Android |

**Zoom and reflow.** 400% browser zoom, and a 320px-wide viewport. No horizontal
scrolling, no clipped content, no overlapping text.

**Reduced motion.** Enable the OS setting; confirm animation stops.

**Forced colours.** Windows High Contrast mode; confirm nothing disappears — a common
failure when meaning is carried by a background colour or a CSS-generated icon.

---

## 6. Definition of done, per feature

A feature is not complete until all of the following hold:

- [ ] Operable by keyboard alone, with visible focus throughout
- [ ] Announced sensibly by VoiceOver
- [ ] Zero axe violations, component and page level
- [ ] All state conveyed by something other than colour alone
- [ ] Errors programmatically associated and announced
- [ ] Usable at 400% zoom and 320px width
- [ ] Functions with JavaScript disabled, where the feature is guest-facing
- [ ] Touch targets ≥24×24 CSS px, ≥44×44 by preference
- [ ] Manual pass result recorded in BUILD-LOG.md
