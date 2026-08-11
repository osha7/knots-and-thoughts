---
name: new-component
description: Guide Osha through building a new React component to project standards — semantic markup, a sibling test using renderAccessible, every visual state covered, and a styleguide entry. Use when adding any component under src/components/, or when the user says "new component", "add a component", or "scaffold a component".
---

# New Component

**Teaching mode applies.** Osha writes the code. You explain, point at the spec, review.
Do not write the component. See `CLAUDE.md` → working agreement.

---

## 1. Before any code — decide these together

Ask, and wait for answers:

1. **What is the accessible name and role?** If you cannot state this, the component is not
   designed yet. "A div that shows the venue" is not an answer; "a heading followed by
   address text inside an article labelled by that heading" is.
2. **Which native element expresses this?** `<button>`, `<form>`, `<details>`, `<ul>`,
   `<time>`. Reach for ARIA only when nothing fits — and check first whether the design is
   fighting the platform.
3. **Does it need `"use client"`?** Default no. Interactivity, a browser API, or a hook that
   requires it are the only reasons. "It was easier" is not one.
4. **What are all its visual states?** Enumerate them now — default, hover, focus, error,
   loading, empty, disabled, and every data variant. This list becomes the test list.
5. **What state does it convey, and how — other than by colour?** If the answer is "colour,"
   the design fails WCAG 1.4.1 and FR-34. Fix it before writing anything.

---

## 2. Files to create

```
src/components/<Name>.tsx
src/components/<Name>.test.tsx
```

Beside each other. No barrel file, no `index.ts`. Named export, matching the filename.

---

## 3. Component rules

Point Osha at `CODE-STANDARDS.md §6` and `DESIGN.md §7`. The ones most often missed:

- **Tokens only** for colour and spacing — `bg-surface`, `text-ink-muted`. Tailwind's default
  palette is disabled, so `text-slate-500` will not resolve. That is deliberate.
- **Every interactive target ≥44×44** (SC 2.5.8 requires 24; the design uses 44).
- **Visible focus** — never `outline-none` without a replacement ring.
- **Persistent visible `<label>`** on every input. No placeholder-as-label.
- **Errors** get `role="alert"` *and* `aria-describedby`, and `aria-invalid` only when errored.
  An always-present empty error container announces nothing and helps nobody.
- **Animation** only inside `@media (prefers-reduced-motion: no-preference)`.
- **No `useEffect` for derived state.**
- Under ~250 lines; under 60 lines per function.

---

## 4. Test rules

The test file **must** use `renderAccessible` from `tests/support/renderAccessible.tsx` —
it runs axe and asserts zero violations on every call, so accessibility cannot be skipped.

```tsx
import { screen } from '@testing-library/react';
import { renderAccessible } from '../../tests/support/renderAccessible';
import { NextEventCard } from './NextEventCard';

describe('NextEventCard', () => {
  it('shows the date as the most prominent element', async () => {
    await renderAccessible(<NextEventCard occurrence={scheduled} />);

    expect(screen.getByRole('heading', { level: 2, name: /this wednesday/i }))
      .toBeInTheDocument();
  });

  it('names the timezone rather than showing a bare time', async () => {
    await renderAccessible(<NextEventCard occurrence={scheduled} />);

    expect(screen.getByText(/7:00 PM Central/)).toBeInTheDocument();
  });

  it('announces cancellation as text, not styling', async () => {
    await renderAccessible(<NextEventCard occurrence={cancelled} />);

    expect(screen.getByText(/cancelled/i)).toBeInTheDocument();
  });

  it('shows the approximate area while the address is still hidden', async () => {
    await renderAccessible(<NextEventCard occurrence={addressHidden} />);

    expect(screen.getByText(/Oak Street area/)).toBeInTheDocument();
    expect(screen.queryByText(/412 Oak Street/)).not.toBeInTheDocument();
  });
});
```

Enforce, per `CODE-STANDARDS.md §7`:

- **Query by role and accessible name.** Never `data-testid`, never a class. This is why an
  unlabelled control fails a *functional* test rather than only an axe check.
- **One behavior per test**, named for the behavior.
- **`renderAccessible` called once per visual state** — a component that is accessible when
  idle is frequently inaccessible when errored.
- **No snapshots.**
- **Every test must be able to fail.** Have Osha break the component deliberately and watch
  it go red. A test never seen failing is not trusted.

---

## 5. Styleguide entry

Add the component to `/styleguide` in **every** state (FR-53). This is not optional
bookkeeping — it is where the axe sweep covers all states at once, it is the visual
regression target, and README screenshots come from it.

---

## 6. Before saying it's done

Walk `ACCESSIBILITY.md §6` with Osha:

- [ ] Operable by keyboard alone, focus visible throughout
- [ ] Announced sensibly by VoiceOver
- [ ] Zero axe violations in every state
- [ ] No state conveyed by colour alone
- [ ] Usable at 400% zoom and 320px width
- [ ] Targets ≥44×44
- [ ] Added to `/styleguide`
- [ ] `tests/meta/coverage.test.ts` passes (it fails if the test file is missing)

Then prompt for a `LEARNINGS.md` entry if anything was newly understood — in Osha's own
words, from memory.
