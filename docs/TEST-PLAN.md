# Test Plan

Every component tested. Accessibility asserted automatically on every component and every
page. All of it blocking in CI.

---

## 1. Shape of the suite

The usual pyramid is the wrong shape for this application. The interesting risk is
concentrated in two places — the occurrence resolution algorithm and the authorization
matrix — and both are pure functions. So the base of the pyramid is unusually wide and
unusually cheap.

| Layer | What it covers | Count (est.) | Runtime |
|-------|----------------|-------------:|---------|
| **Domain unit** | Pure logic: resolution, permissions, dates, crypto | ~150 | < 2s |
| **Component** | Every component, incl. mandatory axe assertion | ~40 | ~15s |
| **Integration** | Repositories and services against a real Postgres branch | ~40 | ~30s |
| **E2E** | PRD §7 journeys, in real browsers | ~25 | ~2min |
| **E2E accessibility** | axe on every route, both themes, signed in and out | ~15 | ~45s |

Fast tests run on save. The whole suite runs in CI on every push.

---

## 2. Tooling

| Purpose | Tool |
|---------|------|
| Unit and component runner | Vitest |
| Component rendering | React Testing Library |
| Component accessibility | `vitest-axe` |
| Page accessibility | `@axe-core/playwright` |
| E2E | Playwright (Chromium, Firefox, WebKit) |
| Static accessibility | `eslint-plugin-jsx-a11y`, strict preset |
| Integration database | Neon branch, created per CI run |
| Secret scanning | `gitleaks` |
| Coverage | `@vitest/coverage-v8` |

---

## 3. Domain unit tests

Pure functions, no database, no mocks. These are the cheapest and highest-value tests in
the project.

### 3.1 Occurrence resolution — `resolveOccurrences`

`now` is always injected (ARCHITECTURE §4), so every case below is deterministic.

**Inheritance**

- No override rows → all fields inherit from the series
- Override with only `notes` set → time, venue, and host still inherit
- Override with `startTimeLocalOverride` → time overridden, everything else inherits
- Override setting every field → nothing inherits
- `overriddenFields` accurately lists exactly which fields were overridden *(this drives
  FR-33, so an error here produces a lying admin UI)*

**Date generation**

- Returns exactly `count` occurrences
- All returned dates fall on `series.dayOfWeek`
- Starting from a Wednesday includes that same day, not the following week
- Starting the day after a Wednesday skips to the next one
- Correct across a month boundary
- Correct across a year boundary
- Correct across a leap day (2028-02-29 is a Tuesday; the Wednesdays either side must be
  right)

**Daylight saving — the cases that matter**

- 2026-10-28 at 19:00 America/Chicago resolves to `2026-10-29T00:00Z` (CDT, −05:00)
- 2026-11-04 at 19:00 America/Chicago resolves to `2026-11-05T01:00Z` (CST, −06:00)
- Both display as "7:00 PM" — *the same stored wall-clock time yields different UTC
  instants, and that is correct*
- Spring transition, 2027-03-14: the Wednesdays either side both display 19:00
- A series whose time falls inside the nonexistent spring-forward hour (02:30) resolves
  without throwing
- A series whose time falls inside the repeated autumn hour (01:30) resolves to the first
  occurrence, deterministically

**Status and cancellation**

- A cancelled occurrence is returned, not omitted — guests must see the tombstone
- `cancelReason` surfaces
- A cancelled occurrence still counts toward `count`

**Address reveal**

- `revealAddressAt` null → `addressVisible: true`
- `revealAddressAt` in the future relative to injected `now` → `addressVisible: false`
- `revealAddressAt` exactly equal to `now` → visible (boundary is inclusive)
- One second before → not visible

### 3.2 Authorization — `can()`

**Exhaustive by construction.** A table-driven test iterating every
(role × capability) pair, asserted against a literal expected matrix transcribed from
PRD §6. 4 roles × 14 capabilities = 56 assertions, and adding a capability without
updating the matrix fails the build.

Plus the row-level cases:

- Host + `occurrence.editOwn` + resource they host → allowed
- Host + `occurrence.editOwn` + resource hosted by someone else → denied
- Host + `occurrence.editOwn` + resource with `hostId: null` → denied
- Host + `occurrence.editAny` → denied regardless of resource
- Host + `occurrence.reassignHost` → denied *(privilege escalation path)*
- Editor + `occurrence.editOwn` + someone else's resource → allowed (Editor has
  `editAny`)
- Viewer + every write capability → denied
- Owner + every capability → allowed
- Capability requiring a resource, called with `undefined` resource → denied, never
  throws *(fail closed)*

### 3.3 Guardrail invariants

- Demoting the last Owner → rejected
- Removing the last Owner → rejected
- Demoting an Owner while another exists → allowed
- An Owner changing their own role → rejected
- Deactivating the last Owner → rejected

### 3.4 Crypto and session

- Argon2id verify returns true for the correct passphrase, false otherwise
- Hash output differs across two hashes of the same input (salted)
- Session cookie round-trips
- Tampered payload fails verification
- Tampered signature fails verification
- Cookie with a stale `passphraseVersion` fails
- Cookie older than 30 days fails
- Signature comparison uses `timingSafeEqual`
- `HMAC(ip)` is stable for one input and differs across inputs
- Calendar token generation yields ≥256 bits and never repeats across 10,000 draws

### 3.5 Error scrubbing (OBSERVABILITY §4)

- `/api/calendar/abc123.ics` → `/api/calendar/[token]`
- Query strings stripped entirely
- `context` keys in the denylist removed, including when nested
- Fingerprints group `Occurrence abc123 not found` with `Occurrence def456 not found`
- Fingerprints do **not** group genuinely different messages
- `reportError` never throws, even when the database is unreachable

---

## 4. Component tests — every component, accessibility included

### The mechanism that makes it non-optional

A shared render helper that asserts accessibility on every use. There is no way to render
a component in a test without the axe check running.

```ts
// tests/support/renderAccessible.tsx
import { render, type RenderOptions } from '@testing-library/react';
import { axe } from 'vitest-axe';
import { expect } from 'vitest';

/**
 * Renders a component AND asserts zero accessibility violations.
 * Use this instead of RTL's render() in every component test.
 * The axe assertion is not opt-out by design — see ACCESSIBILITY.md §5.
 */
export async function renderAccessible(ui: React.ReactElement, options?: RenderOptions) {
  const result = render(ui, options);
  expect(await axe(result.container)).toHaveNoViolations();
  return result;
}
```

Any component with more than one visual state gets the helper called per state, because a
component that is accessible when idle can easily be inaccessible when errored — an
unlabelled spinner, an error message not associated with its field.

### The check that catches an untested component

```ts
// tests/meta/coverage.test.ts
// Fails if any component lacks a sibling test file.
// Mechanically enforces "every component is tested" — see TEST-PLAN §4.
const components = await glob('src/components/**/*.tsx', { ignore: '**/*.test.tsx' });
const missing = components.filter(
  (f) => !existsSync(f.replace(/\.tsx$/, '.test.tsx')),
);
expect(missing, `Components without tests:\n${missing.join('\n')}`).toEqual([]);
```

Combined, these two give *every component has an accessibility test* by construction
rather than by anyone remembering.

### Per-component requirements

Every component test asserts, at minimum:

1. Renders its expected accessible content — queried by role and accessible name, never
   by test id or class
2. Zero axe violations in every visual state
3. Keyboard operability, if interactive
4. State conveyed by something other than colour alone, where it has state

**Specific components and their non-obvious cases:**

| Component | Cases beyond the baseline |
|-----------|---------------------------|
| `PassphraseForm` | Error state associates the message via `aria-describedby` **and** `role="alert"`; `aria-invalid` present only when errored; **paste is not blocked** (FR-7 / SC 3.3.8); `autocomplete="current-password"` present; show/hide toggle is a `<button>` with `aria-pressed`; value preserved and focus returned on error |
| `NextEventCard` | Renders `<time datetime>`; timezone named in visible text; cancelled state announced as text, not strikethrough; approximate area shown when `addressVisible` is false; accessibility notes rendered when present |
| `UpcomingList` | Semantic `<ul>`/`<li>`; empty state renders explanatory text, never an empty region |
| `CancelledBadge` | Conveys state textually; not colour-dependent |
| `InheritedFieldIndicator` | **Highest-risk component in the project.** Inherited vs. overridden conveyed by accessible text or an icon with an accessible name (FR-34); "revert to default" is a real `<button>` ≥24×24; distinguishable in forced-colours mode |
| `OccurrenceEditForm` | Error summary at top with `role="alert"`; focus moves to the summary on failure; every field has a persistent visible `<label>`; no placeholder-as-label |
| `ReadOnlyOccurrence` | Renders a *visible and screen-reader-available* reason why it cannot be edited; does not rely on a `disabled` control to explain itself |
| `RoleSelect` | Native `<select>` with a real label; options carry accessible descriptions of each role |
| `CalendarSubscribeButton` | Token shown once with an accessible copy affordance; copy confirmation announced via a polite live region |
| `VenueForm` | Accessibility-notes field is prominent, not hidden behind a disclosure (ACCESSIBILITY §4) |
| `ErrorBoundaryFallback` | Renders a heading and a recovery action; announced on mount |
| `SkipLink` | First focusable element; visible on focus; targets `#main` |
| `Footer` | Privacy and transparency links present, in consistent position (SC 3.2.6) |

---

## 5. Integration tests

Against a real Postgres — a Neon branch created per CI run, not a mock. Prisma mocking
proves your mocks work, not your queries.

- Every repository: create, read, update, and the constraint failures
- `@@unique([seriesId, date])` rejects a duplicate override
- Removing an organizer sets `AuditEntry.actorId` to null and preserves the entry
- Passphrase rotation increments version and retires the previous row atomically
- Calendar token lookup by hash; revoked token returns nothing
- Rate limit counting respects the window boundary precisely
- `AuthAttempt` pruning deletes rows older than 24h and nothing newer
- Service-layer transactions roll back fully on a mid-operation failure
- `ErrorReport` upsert increments rather than inserting a duplicate

**Server Action authorization — one test per action, no exceptions.** For every Server
Action, assert that it rejects when called with a session lacking the required capability.
Server Actions are public HTTP endpoints (D-18); a hidden button is not protection. A new
Server Action without this test should fail review.

---

## 6. End-to-end tests

Playwright, one spec per PRD §7 journey.

- **J1** First visit → gate → correct passphrase → details visible
- **J2** Returning visit with a valid cookie → details immediately, no gate
- **J3** Wrong passphrase → error announced, value preserved, no session issued
- **J3b** Eleven rapid failures → lockout with a stated retry time
- **J4** Subscribe → token issued → feed URL returns valid iCalendar
- **J5** Host signs in → own week editable, others read-only with a stated reason
- **J6** Owner edits series default time → non-overridden weeks change, overridden weeks
  do not
- **J7** Owner rotates passphrase → existing guest cookie is rejected on next request
- **J8** Cancel a week → guest sees cancelled state → feed emits `STATUS:CANCELLED`

**Plus, non-journey but load-bearing:**

- **JavaScript disabled** → passphrase gate submits and details render (NFR-3, FR-18).
  Run with `javaScriptEnabled: false`.
- `/privacy` and `/transparency` reachable **with no session cookie** (FR-46). *This is
  the easiest middleware mistake to make and the one most likely to go unnoticed.*
- Both pages linked from the passphrase gate itself (FR-47)
- Every other route redirects to the gate without a session
- Security headers present and correct (ARCHITECTURE §10) — headers regress silently
- `robots.txt` disallows; gated pages send `noindex`; the two transparency pages do not
  (FR-52)
- `/api/health` returns 200 with `"status":"ok"`, and `upcomingCount`
- Cron endpoints reject a request with no `CRON_SECRET`
- Street address never appears in feed output, asserted against the raw `.ics` body
  (FR-23) — a direct regression guard on D-12

---

## 7. Accessibility in CI

### Page level, every route

```ts
// tests/e2e/accessibility.spec.ts
const ROUTES = ['/', '/privacy', '/transparency'];
const ADMIN_ROUTES = ['/admin/schedule', '/admin/venues', '/admin/organizers',
                      '/admin/settings', '/admin/errors'];

for (const theme of ['light', 'dark'] as const) {
  for (const route of ROUTES) {
    test(`${route} has no accessibility violations (${theme})`, async ({ page }) => {
      await page.emulateMedia({ colorScheme: theme });
      await page.goto(route);
      const results = await new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'])
        .analyze();
      expect(results.violations).toEqual([]);
    });
  }
}
```

Admin routes run the same sweep with an authenticated storage state, once per role — a
Host's read-only schedule view is different markup from an Editor's, and it can fail
independently.

### Also asserted in CI

- **Reflow** — 320px viewport, no horizontal scroll on any route
- **Zoom** — 400% equivalent, no clipped content
- **Reduced motion** — `prefers-reduced-motion: reduce`, no animation runs
- **Keyboard reachability** — every interactive element on each route is reachable by
  `Tab` and shows a visible focus indicator
- **Target size** — every interactive element's bounding box ≥24×24 CSS px (SC 2.5.8)

### What automation cannot do

Stated plainly because it matters: axe catches roughly 30–40% of real barriers. It will
never tell you the `InheritedFieldIndicator` is incomprehensible without sight. Manual
passes per phase, per ACCESSIBILITY §5, recorded in BUILD-LOG.md. **A green CI run is not
a claim of accessibility.**

---

## 8. CI pipeline

`.github/workflows/ci.yml`. All five jobs required by branch protection on `main`.

```yaml
name: CI
on:
  push: { branches: [main] }
  pull_request:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  static:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 22, cache: npm }
      - run: npm ci
      - run: npx prisma generate
      - run: npm run typecheck          # tsc --noEmit
      - run: npm run lint               # includes jsx-a11y, warnings = errors
      - run: npm run format:check
      - uses: gitleaks/gitleaks-action@v2   # public repo: no committed secrets

  unit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 22, cache: npm }
      - run: npm ci
      - run: npx prisma generate
      - run: npm run test:unit -- --coverage
      # Includes component tests, each asserting zero axe violations,
      # and tests/meta/coverage.test.ts which fails on any untested component.
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: coverage, path: coverage/ }

  integration:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: neondatabase/create-branch-action@v5
        id: branch
        with:
          project_id: ${{ secrets.NEON_PROJECT_ID }}
          branch_name: ci-${{ github.run_id }}
          api_key: ${{ secrets.NEON_API_KEY }}
      - uses: actions/setup-node@v4
        with: { node-version: 22, cache: npm }
      - run: npm ci
      - run: npx prisma migrate deploy
        env: { DATABASE_URL: "${{ steps.branch.outputs.db_url }}" }
      - run: npm run test:integration
        env: { DATABASE_URL: "${{ steps.branch.outputs.db_url }}" }
      - uses: neondatabase/delete-branch-action@v3
        if: always()
        with:
          project_id: ${{ secrets.NEON_PROJECT_ID }}
          branch: ci-${{ github.run_id }}
          api_key: ${{ secrets.NEON_API_KEY }}

  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: neondatabase/create-branch-action@v5
        id: branch
        with:
          project_id: ${{ secrets.NEON_PROJECT_ID }}
          branch_name: e2e-${{ github.run_id }}
          api_key: ${{ secrets.NEON_API_KEY }}
      - uses: actions/setup-node@v4
        with: { node-version: 22, cache: npm }
      - run: npm ci
      - run: npx playwright install --with-deps
      - run: npx prisma migrate deploy && npm run db:seed:test
        env: { DATABASE_URL: "${{ steps.branch.outputs.db_url }}" }
      - run: npm run build && npm run test:e2e
        env:
          DATABASE_URL: "${{ steps.branch.outputs.db_url }}"
          # test-only secrets, never reused anywhere real
      - uses: actions/upload-artifact@v4
        if: failure()
        with: { name: playwright-report, path: playwright-report/ }
      - uses: neondatabase/delete-branch-action@v3
        if: always()
        with:
          project_id: ${{ secrets.NEON_PROJECT_ID }}
          branch: e2e-${{ github.run_id }}
          api_key: ${{ secrets.NEON_API_KEY }}

  accessibility:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # Same setup as e2e, then:
      - run: npm run test:a11y      # @axe-core/playwright sweep, all routes, both themes
      - uses: actions/upload-artifact@v4
        if: failure()
        with: { name: a11y-report, path: a11y-report/ }
```

**Accessibility is a separate named job on purpose.** When it fails, the pull request says
`accessibility — failing`, not `e2e — failing`. Naming the failure is what makes it get
fixed rather than retried.

### Branch protection on `main`

- All five jobs must pass
- Branch must be current with `main`
- No force push, no deletion
- Vercel preview deployment must succeed

---

## 9. Coverage

| Path | Threshold |
|------|-----------|
| `src/domain/**` | **100%** — pure functions with no excuse for gaps |
| `src/services/**` | 90% |
| `src/data/**` | 80% |
| `src/components/**` | 90% |
| `src/lib/**` | 90% |
| Overall | 85% |

Coverage is a smoke detector, not a goal. 100% on `src/domain/` is achievable and
meaningful because those functions are pure; demanding it elsewhere would produce tests
written to satisfy an instrument.

---

## 10. Definition of done, per pull request

- [ ] Every new component has a sibling test file (enforced by `tests/meta`)
- [ ] Every component test uses `renderAccessible`
- [ ] Every visual state of every component asserted
- [ ] Every new Server Action has a test proving it rejects insufficient capability
- [ ] New domain logic at 100% coverage
- [ ] New route added to the accessibility sweep route list
- [ ] Manual keyboard pass performed
- [ ] VoiceOver pass performed
- [ ] Result recorded in BUILD-LOG.md
- [ ] **If this changes what data is collected, `/privacy` and `/transparency` updated in
      this same pull request** (TRANSPARENCY-PAGES §7)
