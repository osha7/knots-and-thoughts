# Public Transparency Pages — Structure and Draft Copy

Two publicly reachable pages, outside the passphrase gate, giving visitors the full
policy *and* the reasoning behind it.

Draft copy below is intended to ship close to as-written.

---

## 1. Why two pages, and why public

### Public, not gated

**Both pages sit outside the passphrase gate.** Gating the explanation of what you
collect behind the very thing you are asking people to trust is backwards. Somebody
deciding whether to type a passphrase into an unfamiliar site should be able to read the
policy *first*.

This costs nothing. Neither page contains event details, addresses, or anything else
worth protecting.

### Publishing the security design is safe

Describing how the authentication and encryption work does not weaken them. That is
Kerckhoffs's principle: a system whose security depends on its own design being secret is
not secure. Our secrets are the keys and the passphrase, and those stay secret. The
*design* is already public in the repository (D-13), so documenting it plainly costs
nothing and buys real trust.

### Two pages rather than one

| Page | Audience | Length |
|------|----------|--------|
| `/privacy` | Every friend, on a phone, in 60 seconds | ~400 words, plain language |
| `/transparency` | Anyone who wants the reasoning | As long as it needs to be |

One combined page would either be too long for the first audience or too thin for the
second. They are cross-linked in both directions.

---

## 2. Requirements these pages add

Appending to PRD §8.

- **FR-46** `/privacy` and `/transparency` are reachable **without** entering the
  passphrase.
- **FR-47** Both are linked from the passphrase gate itself, before any credential is
  requested.
- **FR-48** Both are linked from the same relative position in the footer of every page.
  *(WCAG 2.2 SC 3.2.6 Consistent Help.)*
- **FR-49** Each page displays a "last updated" date and links to its public revision
  history on GitHub.
- **FR-50** Both render fully without JavaScript. Expandable sections use native
  `<details>`/`<summary>`.
- **FR-51** Each page carries an in-page table of contents linking to its section
  headings.
- **FR-52** Neither page loads any third-party resource, and both are exempt from the
  `noindex` rule — *these* pages may be indexed, since they contain nothing private and
  being findable is the point.

**FR-52 deserves a note:** every other page sends `X-Robots-Tag: noindex` (FR-9). These
two are the deliberate exception. There is no reason to hide a privacy policy from a
search engine, and a policy nobody can find is not transparency.

---

## 3. Accessibility of these pages specifically

Policy pages are where accessibility quietly collapses — long prose, nested accordions,
and dense legal formatting.

- **Native `<details>`/`<summary>`** for expandable detail. Keyboard operable and
  screen-reader announced with no JavaScript and no ARIA.
- **Real heading hierarchy**, so screen reader users can jump by heading. This is the
  primary navigation mechanism for a long document.
- **Table of contents** with in-page anchors — helps keyboard and screen reader users far
  more than it helps sighted mouse users.
- **Short sentences, common words.** Plain language is an accessibility feature, not a
  stylistic preference. It serves people with cognitive disabilities, non-native English
  speakers, and anyone reading on a phone while walking.
- **Tables get real `<th>` and `scope`.** Do not lay out policy in a grid of divs.
- **No em-dash-heavy legalese.** Where a term is unavoidable, define it inline.

---

## 4. `/privacy` — draft copy

> # Privacy
>
> *Last updated: [DATE]. [See every change ever made to this page →](https://github.com/osha7/knots-and-thoughts/commits/main/app/privacy/page.tsx)*
>
> **Short version: this site knows nothing about you.** No account, no name, no email,
> no tracking.
>
> [Skip to: What we store · What we never store · Things you should know · Check for yourself]
>
> ## What we store
>
> **A cookie**, once you enter the passphrase. It holds a number and a date. It does not
> hold your name, an ID, or anything that could identify you. It lasts 30 days.
>
> **If you add the calendar subscription:** a random code. We store it scrambled, using a
> one-way process, so even we cannot recover the original. Nothing connects that code to
> you. You can also give it a nickname like "my phone" if you want — that is entirely
> optional and you choose the words.
>
> That is the complete list.
>
> ## What we never store
>
> - Your name
> - Your email address
> - Your phone number
> - Your IP address
> - Which pages you looked at, or when
> - Anything at all about your device
>
> There are no analytics on this site. No advertising. No third-party scripts of any
> kind. Nothing loads from anywhere except this site.
>
> ## Things you should know
>
> We would rather tell you these than let you assume otherwise.
>
> **The passphrase can be forwarded.** Anyone who has it can send it to anyone else, and
> we would have no way of knowing. Please keep it inside the group. If we ever think it
> has spread, we will change it and tell you.
>
> **If you subscribe with Google Calendar or Outlook, those companies see the event
> listing.** That is because *their* servers fetch the calendar, not your phone. It is how
> those products work and we cannot change it. This is why the calendar only ever contains
> a place *name* — never a street address. If you would rather Google not see it, Apple
> Calendar and most desktop calendar apps fetch from your own device instead.
>
> **Home addresses appear only on this website.** Never in the calendar. Sometimes only in
> the last few days before the gathering, if the host prefers.
>
> **Two companies run this site for us.** Vercel serves the pages; Neon stores the
> database. Addresses are encrypted before they are stored, so even a copy of the database
> would not reveal them.
>
> ## Check for yourself
>
> You do not have to take our word for any of this. **The complete source code is
> public:**
>
> [github.com/osha7/knots-and-thoughts](https://github.com/osha7/knots-and-thoughts)
>
> If you or a friend can read code, you can confirm there is no table storing anything
> about visitors. That is the point of publishing it.
>
> ## Questions
>
> Ask in the group chat. There is deliberately no contact form here, because a contact
> form would mean collecting your email address.
>
> ---
>
> **Want the longer reasoning?** [Read why we built it this way →](/transparency)

---

## 5. `/transparency` — draft copy

> # How this site works, and why
>
> *Last updated: [DATE]. [Full revision history →](https://github.com/osha7/knots-and-thoughts/commits/main/app/transparency/page.tsx)*
>
> This page explains the decisions behind this site — not just what it does, but why it
> was built that way, and what it deliberately does *not* do.
>
> [Contents: The principle · The passphrase · Your calendar · Addresses · Who can change things · What we could do but don't · What we cannot promise · Verify it yourself]
>
> ## The principle we built on
>
> There are two kinds of privacy promise.
>
> The first is a promise about **behaviour**: "we will not share your data." It depends on
> us continuing to behave well, and on every future person who touches this site behaving
> well too. You have no way to check it.
>
> The second is a fact about **construction**: "there is no place in this system where
> your name could be stored." That one does not depend on anyone's good intentions. It can
> be checked.
>
> Wherever we had the choice, we built the second kind. The reason we publish the source
> code is so the difference is not something you have to trust us about.
>
> ## The passphrase, and what it does and doesn't do
>
> <details>
> <summary>Why one shared passphrase instead of individual accounts</summary>
>
> Individual accounts would let us revoke one person's access without affecting anyone
> else, and would tell us who shared what. But they would require collecting an email
> address or a phone number from every friend — which is exactly the information we
> decided not to hold. Accounts would also mean signup forms, password resets, and
> forgotten-login emails, for an event you attend on a Wednesday.
>
> We chose the option that collects nothing.
> </details>
>
> <details>
> <summary>What the passphrase actually protects against</summary>
>
> It stops a stranger who finds the web address from seeing where people live. It stops
> search engines from listing the address. Those are real and worth having.
>
> **It does not stop the passphrase itself from spreading.** Once a friend has it, they
> can pass it on, and we would never know. We are telling you this because a security
> measure you misunderstand is worse than one you understand the limits of.
> </details>
>
> <details>
> <summary>How the passphrase is stored</summary>
>
> It is not stored. What is stored is the result of running it through **Argon2id**, a
> one-way function designed specifically to be slow and memory-hungry so that guessing
> attempts are expensive. When you type the passphrase, we run the same process and compare
> results.
>
> Nobody — including us — can read the passphrase out of the database. If we all forgot it,
> we would have to set a new one.
>
> We also limit guessing: ten wrong attempts from one network in fifteen minutes, then a
> pause. There is deliberately no CAPTCHA, because CAPTCHAs exclude people with
> disabilities and rate limiting achieves the same thing.
> </details>
>
> ## Your calendar subscription
>
> <details>
> <summary>How it works without knowing who you are</summary>
>
> When you tap "add to calendar," your browser is given a long random code — about as
> unguessable as a very long password. Your calendar app quietly fetches the schedule using
> that code every so often, which is why it stays up to date when a host changes something.
>
> We keep only a scrambled version of that code, so we can recognise it when your calendar
> asks, but cannot reproduce it. We keep the date it was created. **We do not keep an email
> address, a name, or an IP address, because we never ask for any.**
>
> If a code ever leaks, we can switch off that one code without disturbing anybody else's.
> </details>
>
> <details>
> <summary>The Google Calendar problem, explained honestly</summary>
>
> Calendar subscriptions work by an app periodically fetching a web address.
>
> With **Apple Calendar** and most desktop calendar apps, *your device* does the fetching.
> Nobody else is involved.
>
> With **Google Calendar and Outlook.com**, *their servers* do the fetching, then sync to
> your phone. That means Google or Microsoft retrieves and stores the event listing.
>
> We cannot change this. It is how those products are built. What we did instead was make
> sure the calendar listing contains nothing sensitive: the place *name* ("Sam's place")
> and a link back to this site. **The street address is never in the calendar feed** —
> only on this website, behind the passphrase.
>
> So if you subscribe with Google, Google learns that a gathering happens on Wednesdays at
> a place called "Sam's place." It does not learn where that is.
> </details>
>
> ## Addresses
>
> <details>
> <summary>Why addresses get special treatment</summary>
>
> Some gatherings are at public places. Some are at people's homes. A home address is
> different in kind from a bar's address — it is where somebody sleeps.
>
> So addresses are handled separately from everything else on this site:
>
> - They are **encrypted** before being stored, so a stolen copy of the database does not
>   reveal them.
> - They are **never included in the calendar feed**, for the reason above.
> - They are **never written into our logs or error reports**, which are automatically
>   scrubbed.
> - A host can choose to **hide the exact address until a few days before**, so guests see
>   only the neighbourhood until then.
> </details>
>
> ## Who can change things, and why it is split up
>
> <details>
> <summary>The four roles</summary>
>
> Not everyone who helps organise needs the power to do everything.
>
> - **Owner** — can do everything, including adding and removing organisers and changing
>   the passphrase.
> - **Editor** — can change any week's details, but cannot add or remove organisers.
> - **Host** — can change **only the weeks they are hosting.** They cannot touch anybody
>   else's week, and cannot hand their week to someone else or take one that isn't theirs.
> - **Viewer** — can see the full schedule but change nothing.
>
> The Host role exists so that whoever is hosting can fix their own details without needing
> anyone's help, and without being able to affect anyone else. Every change is recorded
> with who made it and when.
> </details>
>
> ## Things we could do, and chose not to
>
> <details>
> <summary>Analytics</summary>
>
> We could know how many people visit, when, and from where. Every site does. We decided
> that knowing was not worth collecting it for. There is no analytics code here at all —
> which also makes the site faster.
> </details>
>
> <details>
> <summary>Error tracking services</summary>
>
> Most sites send crash reports to a company like Sentry. Useful for developers. But those
> reports include the web addresses being visited — and one of ours contains your personal
> calendar code. Sending those to another company would mean handing over your access
> codes.
>
> So crash reports are stored in our own database instead, with codes stripped out before
> anything is written down.
> </details>
>
> <details>
> <summary>Text message reminders</summary>
>
> We would have to collect phone numbers, and it is the only part of this that would cost
> money. Both were reasons to skip it. The calendar subscription does the same job without
> either.
> </details>
>
> <details>
> <summary>Email reminders</summary>
>
> Not yet, and not casually. Sending emails means holding email addresses, which would
> break the promise at the top of this page. If we ever add it, it will be clearly optional
> and this page will say exactly what is stored — before it launches, not after.
> </details>
>
> ## What we cannot promise
>
> Every site's privacy page should have this section. Most do not.
>
> 1. **We cannot stop the passphrase from spreading.** Anyone who has it can share it.
> 2. **We cannot stop Google or Microsoft from seeing the calendar listing** if you
>    subscribe using their products. We can and do keep addresses out of it.
> 3. **We depend on two companies.** Vercel serves the site and Neon stores the data. Both
>    are audited under a standard called SOC 2, and addresses are encrypted before storage
>    — but we are not the only ones holding the box.
> 4. **Our host's own server logs record IP addresses** briefly, as every web host's do.
>    Our own database never does. We do not control theirs.
>
> ## Verify it yourself
>
> The whole point of publishing this is that you should not have to trust it.
>
> **Source code:** [github.com/osha7/knots-and-thoughts](https://github.com/osha7/knots-and-thoughts)
>
> Useful places to look, if you or a friend reads code:
>
> - `prisma/schema.prisma` — every piece of data this site can store. Look for a table
>   holding visitor information. There isn't one.
> - `app/api/calendar/[token]/route.ts` — confirm the calendar feed contains no street
>   address.
> - `src/lib/logger.ts` — the list of things that are stripped before anything is logged.
>
> **This page's own history** is public too, so you can see whether we ever quietly changed
> what we promised: [revision history](https://github.com/osha7/knots-and-thoughts/commits/main/app/transparency/page.tsx)
>
> ---
>
> [← Back to the short privacy summary](/privacy)

---

## 6. Implementation notes

- Both pages are static Server Components. No data fetching, no client JavaScript.
- Middleware must **exempt** `/privacy` and `/transparency` from the passphrase check.
  This is the single easiest thing to get wrong here, and it gets an e2e test asserting
  both are reachable with no session cookie.
- Both pages **override** the global `noindex` header (FR-52).
- The "last updated" date is derived at build time from the file's git commit date rather
  than typed by hand, so it cannot silently go stale.
- The GitHub revision-history links must be verified after the repository is created —
  they will 404 until it exists and is public.
- Content lives in the page components rather than a CMS, so that the git history *is*
  the changelog. That is what makes FR-49 meaningful.

---

## 7. A standing rule

**Any change that causes new data to be collected must update these pages in the same
pull request.** Not afterwards. If a future feature adds an email field, the privacy page
changes in the same commit — otherwise the page silently becomes a false statement, which
is worse than never having made the promise.

Worth adding to the pull request template as a checkbox.
