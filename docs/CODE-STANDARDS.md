# Code Standards

Three layers, in order of reliability:

1. **Tooling config** — strict by default, so bad code does not compile
2. **Hooks** — run automatically on every file Claude edits, so drift is corrected immediately
3. **This document** — the rules that need reasoning rather than automation

The ordering is deliberate. A rule enforced by a type error is worth ten rules written down.
Anything in layer 3 that *could* move to layer 1 or 2 should.

---

## 1. What "slop" means here, concretely

Naming the failure modes so the rules have a target. These are the patterns that make code
look machine-generated, and most of them are mechanically detectable.

| Pattern | Why it's bad |
|---------|--------------|
| Comments restating the code (`// increment the counter`) | Pure noise. Goes stale, adds nothing. |
| JSDoc on self-evident functions | Same, with ceremony. |
| `any`, or `as` used to silence an error | Discards the reason you chose TypeScript. |
| `try/catch` that swallows and continues | Converts a loud bug into a silent one. |
| An interface with one implementor | Abstraction with no abstraction. |
| Barrel files (`index.ts` re-exports) | Obscures where things live; breaks tree-shaking. |
| Premature generalization ("we might need…") | You won't. Delete it. |
| `useEffect` for derived state | Almost always a `useMemo` or plain expression. |
| Dead or commented-out code | Git remembers. Delete it. |
| Snapshot tests | Get regenerated blindly when they fail. Actively harmful. |
| `expect(true).toBe(true)` and friends | A test that cannot fail is a lie about coverage. |
| Tests querying by `data-testid` or class | Tests implementation, not behavior. And bypasses the accessibility tree. |
| Inconsistent naming for one concept | `getUser` / `fetchUser` / `retrieveUserData` |
| Functions doing five things | Unreviewable and untestable in isolation. |
| Section-divider comment banners | Use files and functions, not ASCII art. |

**The one-line test:** if a reader would learn nothing from a line, it should not exist.

---

## 2. TypeScript

```jsonc
// tsconfig.json — compilerOptions
{
  "strict": true,
  "noUncheckedIndexedAccess": true,
  "exactOptionalPropertyTypes": true,
  "noImplicitOverride": true,
  "noFallthroughCasesInSwitch": true,
  "noPropertyAccessFromIndexSignature": true,
  "verbatimModuleSyntax": true
}
```

### Rules

- **No `any` in application code.** Not `// eslint-disable`, not `as any`. If a type is
  genuinely unknown, use `unknown` and narrow it. The one permitted exception is a test
  fixture where the shape is irrelevant, and even then prefer a partial type.
- **No type assertions to silence errors.** `as` is legitimate for narrowing a known union
  and for `as const`. It is not legitimate as a way to stop the compiler complaining. If you
  reach for it, the type is wrong somewhere upstream.
- **Prefer `type` over `interface`** unless you need declaration merging. Consistency beats
  the marginal differences.
- **Return types on exported functions.** Inference is fine internally; at a module boundary
  an explicit return type is documentation that cannot go stale.
- **`satisfies` over annotation** when you want inference *and* a constraint.
- **Discriminated unions over optional-field soup.** `{ status: 'cancelled', reason: string }
  | { status: 'scheduled' }` beats `{ cancelled: boolean, reason?: string }`, because the
  invalid combination becomes unrepresentable.

`noUncheckedIndexedAccess` is the one people disable. Keep it. It is precisely what forces
the occurrence-merge code to be honest about lookups that might miss.

---

## 3. ESLint

```js
// eslint.config.mjs — the rules that matter beyond the Next.js defaults
export default [
  // …next/core-web-vitals, typescript-eslint strictTypeChecked, jsx-a11y strict

  {
    rules: {
      // Types
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-unsafe-assignment': 'error',
      '@typescript-eslint/no-unsafe-member-access': 'error',
      '@typescript-eslint/no-unnecessary-condition': 'error',
      '@typescript-eslint/consistent-type-imports': 'error',
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],

      // Async correctness — these catch real bugs, not style
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/no-misused-promises': 'error',
      '@typescript-eslint/await-thenable': 'error',
      '@typescript-eslint/require-await': 'error',

      // Slop
      'no-console': 'error',              // use src/lib/logger.ts
      'no-warning-comments': ['error', { terms: ['todo', 'fixme'], location: 'anywhere' }],
      'complexity': ['error', 12],
      'max-lines-per-function': ['error', { max: 60, skipBlankLines: true }],
      'max-depth': ['error', 3],
      'no-nested-ternary': 'error',

      // Imports
      'import/order': ['error', { 'newlines-between': 'always',
                                  alphabetize: { order: 'asc' } }],
      'import/no-default-export': 'error',   // except pages/layouts, overridden below

      // Layering (ARCHITECTURE §2) — enforced, not trusted
      'no-restricted-imports': ['error', {
        patterns: [
          { group: ['**/data/**', '@prisma/client', '**/app/**'],
            message: 'src/domain must stay pure — no I/O imports. See ARCHITECTURE §2.' },
        ],
      }],
    },
  },

  // Tests
  {
    files: ['**/*.test.ts', '**/*.test.tsx'],
    rules: {
      'testing-library/no-node-access': 'error',
      'testing-library/prefer-screen-queries': 'error',
      'jest-dom/prefer-to-have-text-content': 'error',
      'max-lines-per-function': 'off',
    },
  },
];
```

Plus these plugins: `eslint-plugin-jsx-a11y` (strict), `eslint-plugin-testing-library`,
`eslint-plugin-jest-dom`, `eslint-plugin-import`, `@typescript-eslint` with
`strictTypeChecked`.

**`no-warning-comments` as an error is deliberate.** A `TODO` in a codebase is a decision
deferred with no owner and no date. Either do it, or open an issue and link the issue.

**Warnings are errors in CI.** A warning nobody must fix is a warning nobody fixes.

---

## 4. Prettier

```jsonc
// .prettierrc
{
  "semi": true,
  "singleQuote": true,
  "trailingComma": "all",
  "printWidth": 90,
  "tabWidth": 2,
  "plugins": ["prettier-plugin-tailwindcss"]
}
```

Formatting is never discussed. Prettier decides, the hook applies it, and nobody spends a
review comment on it. `prettier-plugin-tailwindcss` sorts class names so diffs stay
meaningful.

---

## 5. Comments

**Comments explain *why*. Code explains *what*.** If a comment describes what a line does,
delete the comment. If the code needs a comment to be understood, consider whether a better
name or a smaller function would remove the need.

Comments that earn their place:

```ts
// Argon2 would add real latency to every calendar poll and buy nothing —
// the token is already 256 bits of entropy. See SECURITY-PRIVACY §6.
const tokenHash = sha256(token);
```

```ts
// `now` is injected rather than read from the clock so DST-transition
// behaviour is deterministic in tests. See ARCHITECTURE §4.
export function resolveOccurrences({ now, ... }: Input): ResolvedOccurrence[] {
```

Comments that do not:

```ts
// Hash the token          ← restates the code
const tokenHash = sha256(token);

/**
 * Gets the user by ID.    ← says nothing the signature doesn't
 * @param id The ID
 */
```

**Reference document sections rather than re-explaining.** `See DECISIONS.md D-08` is
better than a paragraph that will drift out of sync with the decision record.

Prisma schema comments are an exception worth making: document non-obvious invariants there,
because the schema is read by people who won't read the docs.

---

## 6. React and Next.js

- **Server Components by default.** `"use client"` requires a reason: interactivity, browser
  API, or a hook that needs it. Not "it was easier."
- **No `useEffect` for derived state.** If a value is computable from props or state,
  compute it. Effects are for synchronizing with something outside React.
- **Native elements first.** `<button>`, `<form>`, `<details>`, `<dialog>`. Reach for ARIA
  only when no element expresses the semantics — and then check whether the design is
  fighting the platform.
- **One component per file**, named the same as the file. No barrel files.
- **Named exports**, except for Next.js pages, layouts, and route handlers where the
  framework requires default.
- **Props typed inline** for small components; a named `type` when reused or over ~5 fields.
- **No prop drilling past two levels.** Compose, or use context — but context needs a reason.

---

## 7. Test quality

Tests are code and receive the same standards. Bad tests are worse than no tests: they cost
maintenance and provide false confidence.

- **Query by role and accessible name.** `getByRole('button', { name: 'Save' })`. Never by
  `data-testid`, never by class. This is not stylistic — it means every test exercises the
  accessibility tree, so an unlabelled control fails a *functional* test, not just an axe
  check.
- **No snapshot tests.** When a snapshot fails, the reflex is to regenerate it. A test whose
  failure mode is "press update" is not a test.
- **One behavior per test.** The name states the behavior: `rejects a Host editing a week
  they do not host`, not `test permissions 3`.
- **Arrange, act, assert** — with blank lines between. Reads as three steps because it is.
- **Assert observable behavior, not internals.** Not "was this function called," but "did
  the user-visible outcome happen."
- **No mocking what you own.** Mock the network and the clock. Not your own services — use a
  real database branch instead. Mocking Prisma proves your mocks work.
- **Inject `now`.** Never `vi.useFakeTimers()` when a parameter would do.
- **Every test must be able to fail.** Break the implementation deliberately and confirm the
  test goes red. A test you have never seen fail is a test you cannot trust.

---

## 8. Naming

- One concept, one name. Decide `venue` or `location` and never mix them.
- Booleans read as assertions: `isCancelled`, `hasOverride`, `canEditOccurrence`.
- Functions are verbs; values are nouns. `resolveOccurrences` returns `resolvedOccurrences`.
- No abbreviations except genuinely universal ones (`id`, `url`, `html`). Not `occ`, `usr`,
  `cfg`.
- Domain language, consistently: *series*, *occurrence*, *override*, *venue*, *host*,
  *organizer*, *guest*. These come from the PRD. Do not invent synonyms in code.

---

## 9. Files and structure

- Layering per `ARCHITECTURE.md §2`, enforced by `no-restricted-imports`.
- File names match their export: `resolveOccurrences.ts`, `NextEventCard.tsx`.
- Tests live beside the code: `resolve.ts`, `resolve.test.ts`.
- No file over ~250 lines. Beyond that it is doing too much.
- `knip` in CI to catch unused exports, unused files, and unused dependencies. Dead code is
  slop with tenure.

---

## 10. When to break these rules

Rigid standards produce their own slop — abstraction invented to satisfy a lint rule, a
function split in half to duck a line limit. That is worse than the thing the rule prevented.

Break a rule when following it would make the code *harder to understand*, and say so in a
comment explaining which rule and why:

```ts
// eslint-disable-next-line complexity -- this is the WCAG 2.2 conformance
// matrix; splitting it across functions hides the structure that makes it
// auditable against the spec.
```

**A disable without a `--` reason is not acceptable.** The reason is the whole point: it turns
an escape hatch into a documented decision.

Rules that are genuinely absolute, because breaking them breaks a guarantee rather than a
preference:

- No `any`
- No `console.log` — use the redacting logger
- No secrets in the repository
- No `data-testid` queries in tests
- The layering rule
- No guest PII in the schema

Everything else is a strong default.

---

## 11. Review questions

What to ask of any diff, in priority order:

1. Could this be **deleted** rather than written? Less code is the goal.
2. Does it have a test that can **actually fail**?
3. Is any state conveyed by color alone?
4. Does every Server Action re-verify authorization independently?
5. Is `now` injected rather than read from the clock?
6. Does any comment restate the code?
7. Would a stranger understand this in six months without asking?

Question 1 is first for a reason. The most common improvement to a diff is making it smaller.
