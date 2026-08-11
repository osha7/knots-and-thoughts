# Error Handling

`OBSERVABILITY.md` covers what happens *after* an error — capture, fingerprint, digest.
This document covers what the code does *when it fails*, and what the person in front of it
sees.

These are different problems and the plan originally only addressed the first.

---

## 1. The taxonomy

Most error-handling messes come from treating four different things as one thing.

| Class | Example | Exceptional? | Shape |
|-------|---------|:---:|-------|
| **Expected outcome** | Wrong passphrase; rate limited; no upcoming occurrence | No | **Return a value** |
| **Authorization failure** | Host editing someone else's week | No | **Return a value**, fail closed |
| **Infrastructure failure** | Neon unreachable; Resend timed out | Yes | **Throw**, report, maybe retry |
| **Programmer error** | Invariant violated; unreachable branch reached | Yes | **Throw**, report, generic message |

The line that matters: **an expected failure is not an exception.** A wrong passphrase is
not a crash — it is the ordinary second outcome of "check this passphrase." Modelling it as a
thrown error hides it from the type signature and makes it invisible to the compiler.

---

## 2. Result types in domain and service layers

`verifyPassphrase(): Promise<Session>` is a lie — it can fail three ways and the signature
says none of them. This does not:

```ts
// src/domain/result.ts
export type Result<T, E extends string> =
  | { ok: true; value: T }
  | { ok: false; error: E; detail?: string };

export const ok  = <T>(value: T): Result<T, never> => ({ ok: true, value });
export const err = <E extends string>(error: E, detail?: string): Result<never, E> =>
  ({ ok: false, error, detail });
```

```ts
export function verifyPassphrase(input: {
  submitted: string;
  hash: string;
  attempts: AttemptWindow;
  now: Date;
}): Promise<Result<GuestSession, 'invalid_passphrase' | 'rate_limited'>>;
```

Now the caller cannot forget `rate_limited` — the compiler will not let them, because the
error channel is a union it must narrow.

**Deliberately not a full functional library.** No `fp-ts`, no `neverthrow`, no `map`/
`chain`/`fold` combinators. A discriminated union and two constructors. The goal is
type-visible failure, not a monadic style that every future reader has to learn.

**Errors are string literal unions, not classes.** They serialize across the Server Action
boundary for free, they are exhaustively checkable in a `switch`, and they cannot accidentally
carry a stack trace into a client payload.

### When to throw instead

- The database is unreachable
- An invariant is violated — a state the type system permits but the domain does not
- A configuration value is missing (already handled: `env.ts` throws at boot)

Rule of thumb: **throw when there is no sensible thing for the caller to do about it.**
Return a result when there is.

---

## 3. Server Actions

Server Actions are the boundary between typed server code and a form. They must never throw
an arbitrary error to the client — an unhandled throw in an action produces an opaque digest
in production, which tells the user nothing and you nothing.

Every action returns the same shape:

```ts
// src/lib/actionResult.ts
export type ActionResult<T = undefined> =
  | { status: 'success'; data: T }
  | { status: 'error'; message: string; fieldErrors?: Record<string, string> };
```

`message` is for a `role="alert"` summary. `fieldErrors` maps a field name to a message,
which the form wires to that input via `aria-describedby` (ACCESSIBILITY §3).

Every action follows the same five steps, in this order:

```ts
export async function updateOccurrence(
  _prev: ActionResult | undefined,
  formData: FormData,
): Promise<ActionResult> {
  // 1. Authenticate — before anything else touches input
  const session = await getAdminSession();
  if (!session) return { status: 'error', message: 'Your session has expired. Sign in again.' };

  // 2. Validate. Zod field errors map straight to fieldErrors.
  const parsed = UpdateOccurrenceSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    return {
      status: 'error',
      message: 'Some details need fixing.',
      fieldErrors: flattenZodErrors(parsed.error),
    };
  }

  // 3. Authorize — independently. Never rely on the layout. (D-18, FR-44)
  const occurrence = await occurrenceRepo.findById(parsed.data.id);
  if (!occurrence) return { status: 'error', message: 'That week could not be found.' };
  if (!can(session.actor, 'occurrence.editOwn', { hostId: occurrence.hostIdOverride })) {
    // Same message for "not allowed" and "does not exist" — see §6.
    return { status: 'error', message: 'That week could not be found.' };
  }

  // 4. Execute, converting expected failures to messages and unexpected ones to reports
  try {
    const result = await scheduleService.updateOccurrence(parsed.data, session.actor);
    if (!result.ok) return { status: 'error', message: MESSAGES[result.error] };
  } catch (error) {
    await reportError(error, { route: 'action:updateOccurrence' });
    return { status: 'error', message: GENERIC_FAILURE };
  }

  // 5. Revalidate
  revalidatePath('/admin/schedule');
  return { status: 'success', data: undefined };
}
```

Steps 1 and 3 are the ones that get skipped when an action is written in a hurry. They are why
`TEST-PLAN.md §5` requires one authorization test per action, with no exceptions.

Client side, `useActionState` consumes this — and because the form is a real `<form>` with a
Server Action, it still submits without JavaScript (NFR-3). Without JS the error arrives as a
full page render rather than an update; the markup is identical either way.

---

## 4. Next.js error boundaries

Not previously specified. All four are needed.

| File | Catches | Notes |
|------|---------|-------|
| `app/error.tsx` | Render errors below the root layout | Must be a Client Component. Receives `reset()`. |
| `app/global-error.tsx` | Errors *in* the root layout | Must render its own `<html>` and `<body>` |
| `app/not-found.tsx` | 404, and explicit `notFound()` | |
| `app/admin/error.tsx` | Console-specific failures | Keeps the guest path unaffected by console bugs |

```tsx
// app/error.tsx
'use client';

export default function Error({ error, reset }: { error: Error; reset: () => void }) {
  useEffect(() => {
    void fetch('/api/errors/client', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      // digest, not message — message may contain internals. See §6.
      body: JSON.stringify({ digest: error.digest, route: window.location.pathname }),
    });
  }, [error.digest]);

  return (
    <main id="main">
      <h1>Something went wrong</h1>
      <p>This wasn&apos;t your fault. Try again, and if it keeps happening, tell Osha.</p>
      <button onClick={reset}>Try again</button>
      <p><a href="/">Back to the start</a></p>
    </main>
  );
}
```

Accessibility requirements for every error page, per `ACCESSIBILITY.md`:

- A real `<h1>` — an error page with no heading is unnavigable by screen reader
- A recovery action that is a `<button>` or `<a>`, keyboard operable, ≥44×44
- Plain language. Not "an unexpected error occurred," which tells nobody anything
- Focus moves to the heading on mount, so a screen reader user learns the page changed

**Send `error.digest`, not `error.message`.** In production Next.js replaces the message with
a digest precisely so internals do not reach the browser. Posting the message back would
defeat that.

---

## 5. Retry — narrowly

Neon's free tier suspends when idle (D-03), so the first query after a quiet period can fail
at the connection level rather than merely being slow.

**One retry, connection errors only, reads only.**

```ts
const RETRYABLE = new Set(['P1001', 'P1002', 'P1017']); // unreachable, timeout, closed

export async function withRetry<T>(read: () => Promise<T>): Promise<T> {
  try {
    return await read();
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && RETRYABLE.has(error.code)) {
      await sleep(250);
      return read();            // exactly one retry — a loop turns an outage into a hang
    }
    throw error;
  }
}
```

**Reads only, deliberately.** Retrying a write without idempotency keys risks applying it
twice. A duplicated occurrence override is a worse outcome than a visible error, and the
correct fix for writes is idempotency, not retries.

**One attempt, not exponential backoff.** A retry loop converts a database outage into a hung
request, which the uptime monitor then reports as a timeout rather than a failure.

---

## 6. What the user is allowed to see

**User-facing messages come from a fixed set. Never `error.message` from an unknown error.**
That is exactly how stack traces, connection strings, and internal hostnames end up on
screen.

```ts
// src/lib/messages.ts
export const GENERIC_FAILURE =
  'Something went wrong on our end. Please try again.';

export const MESSAGES = {
  invalid_passphrase: "That passphrase didn't match.",
  rate_limited:       'Too many attempts. Please try again in a few minutes.',
  not_found:          'That week could not be found.',
  session_expired:    'Your session has expired. Please sign in again.',
  forbidden:          'That week could not be found.',   // intentionally == not_found
} as const satisfies Record<string, string>;
```

Three deliberate choices:

**`forbidden` and `not_found` are the same string.** Distinguishing them tells an attacker
which resources exist. The Host who tries to edit someone else's week and the Host who
mistypes an ID should learn exactly the same thing.

**No error codes shown to guests.** "Error ARP-4021" is a support-ticket affordance, and there
is no support desk. It only makes a friend feel they have broken something.

**No "close but not quite" feedback on the passphrase** (FR-5). Any hint about proximity is a
brute-force oracle.

### The one exception

The **admin** console may show slightly more, because organizers are trusted and can act on
it — "The calendar feed could not be generated because this occurrence has no venue" is
actionable. Still no stack traces, and still nothing derived from an unknown error's message.

---

## 7. Logging errors

Per `OBSERVABILITY.md §6`, redaction happens in the logger, not at call sites.

- **Expected outcomes are not logged as errors.** A wrong passphrase at `warn`, with a hashed
  IP. Logging it at `error` trains you to ignore errors.
- **Infrastructure failures** at `error`, and reported via `reportError`.
- **Programmer errors** at `error`, reported, and worth an issue.
- **Never logged:** passphrases, tokens, magic links, session cookies, street addresses, raw
  IPs, organizer emails.

`reportError` never throws (OBSERVABILITY §4). A failure in the reporter must not become the
failure you are chasing.

---

## 8. Requirements

Appending to PRD §8.

- **FR-75** Domain and service functions return `Result` for expected failures; exceptions are
  reserved for infrastructure and programmer errors
- **FR-76** Every Server Action returns `ActionResult` and never throws to the client
- **FR-77** `app/error.tsx`, `app/global-error.tsx`, `app/not-found.tsx`, and
  `app/admin/error.tsx` all exist, each with an `<h1>` and a keyboard-operable recovery action
- **FR-78** User-facing error text comes from the fixed `MESSAGES` set; no unknown error's
  message ever reaches a response body
- **FR-79** `forbidden` and `not_found` are indistinguishable to the client
- **FR-80** Read queries retry exactly once on a connection-level error; writes never retry
- **FR-81** Client error reports send `error.digest`, never `error.message`
- **FR-82** Expected failures are logged below `error` level

## 9. Tests

Adding to `TEST-PLAN.md`:

- Every `Result`-returning function: one test per error variant, and a test that the success
  path returns `ok: true`
- Every Server Action: rejects without a session; rejects without capability; returns
  `fieldErrors` for invalid input; returns `GENERIC_FAILURE` when the service throws
- `forbidden` and `not_found` produce **byte-identical** responses
- `withRetry` retries once on a retryable code, does not retry on others, and does not loop
- Each error boundary renders an `<h1>` and a focusable recovery control, with zero axe
  violations
- No response body in any e2e test contains `at ` followed by a file path — a crude but
  effective stack-trace-leak guard
