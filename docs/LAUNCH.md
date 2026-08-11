# Launch

The human side of shipping: choosing the passphrase, telling forty people, the
add-to-home-screen experience, and the legal footnote.

These are easy to leave until the last evening and then do badly.

---

## 1. Choosing the passphrase

The passphrase is the only thing between a stranger and somebody's home address. It also
has to be sayable in a group chat and typable on a phone.

**Use a Diceware-style phrase: four or five random common words.**

```
copper-lantern-quiet-harbor
```

Why this shape:

- **Genuinely strong.** Four words from a large list is far more entropy than
  `Knots2026!`, which is what people actually pick.
- **Sayable.** Someone can read it aloud without spelling it.
- **Typable on a phone.** No symbol-keyboard hunting, and autocorrect leaves lowercase
  words alone.
- **Pastes cleanly**, which matters because paste must work (FR-7, SC 3.3.8).

**Do not** pick something meaningful to the group. Not the street, not the founding year,
not an inside joke. Meaningful is exactly what a person who knows you would guess first,
and that is the realistic threat here — not a botnet.

Generate it with real randomness, not by choosing words that feel random:

```bash
# 4 random words from the system dictionary
shuf -n 4 /usr/share/dict/words | tr '\n' '-' | tr '[:upper:]' '[:lower:]'
```

**Set it through the admin console, never in an environment variable.** It is stored as an
Argon2id hash (FR-2), so there is no plaintext copy anywhere — including for you. Keep the
phrase in a password manager.

---

## 2. Telling your friends

Forty people need to learn this exists, get the passphrase, and understand the calendar
option. Write this before launch night.

### The message

> **We have a page for Wednesdays now.**
>
> **knotsandthoughts.com** — passphrase: `copper-lantern-quiet-harbor`
>
> It always has this week's time, place, and host, plus the next couple of weeks. No signup,
> no app. Type the passphrase once and your phone remembers you for a month.
>
> **If you want it in your calendar:** tap "Add to your calendar" on the page. It updates
> itself when a host changes something, so you'll never be at the wrong address.
>
> Two things worth knowing:
> - Please keep the passphrase in this group — some Wednesdays are at people's homes.
> - The site collects nothing about you. No name, no email, no tracking. If you're curious
>   how that works: knotsandthoughts.com/privacy

### Why it's shaped that way

- **Passphrase in the same message as the link.** Splitting them across two messages
  guarantees a dozen "what's the password" replies.
- **"Your phone remembers you for a month"** pre-empts the most common confusion — people
  expecting to type it weekly.
- **The calendar benefit stated as an outcome** ("never be at the wrong address"), not a
  feature. Nobody subscribes to a feed because it's a feed.
- **The privacy line last, short, with a link.** Most people won't click. The ones who care
  will, and the fact that it's there does work even unread.
- **"Some Wednesdays are at people's homes"** gives the reason for discretion. A rule with a
  reason gets followed; a rule without one doesn't.

### Expect these questions

Have answers ready:

- *"Do I need an account?"* No.
- *"Does this work on Android?"* Yes, and Google Calendar works for subscribing.
- *"I can't find the calendar thing."* It's the button under the address.
- *"Can I add my partner?"* Yes — share the passphrase, not a separate invite.
- *"Why is the address not showing?"* Some hosts hide it until a few days before.

---

## 3. Add to home screen

Cheap, and meaningful for something checked weekly on a phone. A web app manifest plus
icons makes the site open without browser chrome.

```json
{
  "name": "Knots & Thoughts",
  "short_name": "K&T",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#FBF9F5",
  "theme_color": "#2F5D57",
  "icons": [
    { "src": "/icon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "/icon-512.png", "sizes": "512x512", "type": "image/png" },
    { "src": "/icon-maskable.png", "sizes": "512x512", "type": "image/png",
      "purpose": "maskable" }
  ]
}
```

- Include a **maskable** icon or Android will crop your artwork badly.
- `theme_color` should match `--accent` so the status bar looks intentional.
- **No service worker.** A service worker would cache event details, and stale cached
  details are worse than a slow load — someone could be shown last week's address. The whole
  point of this site is being correct. Skip offline support deliberately.
- Mention it in the launch message only as a P.S. Most people won't bother, and pushing it
  adds friction to the main instruction.

- [ ] `FR-72` A web app manifest and icons exist, including a maskable icon
- [ ] `FR-73` No service worker is registered — stale event data is a correctness risk

---

## 4. The legal footnote

Not legal advice, and worth ten minutes of thought rather than none.

**GDPR** technically applies if any friend is in the EU or UK. Because the site collects no
personal data from guests:

- **No cookie consent banner is required.** The one cookie is strictly necessary for a
  service the user explicitly requested — that is the exemption, and it applies cleanly.
- **Subject access and erasure requests are trivially satisfied**, because there is nothing
  held to disclose or erase.
- Organizer email addresses *are* personal data, held on a legitimate-interest basis for
  site administration. Four people who chose to be administrators. Worth one sentence on
  `/transparency`.

**CCPA** does not apply — no sale of personal information, and the revenue thresholds are
nowhere near met.

**A note worth adding to `/transparency`:** stating plainly that no consent banner is
needed *and why* is more informative than a banner would be, and it demonstrates the
reasoning rather than performing compliance. For a portfolio, that reads well.

**For the print store this changes completely.** Collecting names, shipping addresses, and
payment data brings real obligations: a lawful basis for processing, a data processing
agreement with Stripe, retention periods, and an actual erasure procedure. Do not reuse this
section there.

- [ ] `FR-74` `/transparency` states the cookie-consent position and its reasoning

---

## 5. Launch day

In order.

- [ ] Set the real passphrase through the console; store it in a password manager
- [ ] Seed the real series: day, time, **timezone confirmed**, default venue, default host
- [ ] Create the real venues, with accessibility notes filled in
- [ ] Confirm the second Owner has signed in successfully
- [ ] Open the site on a real phone, on cellular, not wifi
- [ ] Subscribe a calendar on iOS and confirm the event appears correctly
- [ ] Confirm uptime monitors are green and have alerted at least once in testing
- [ ] Re-read `/privacy` and `/transparency` for accuracy as of today
- [ ] Send the message

### The following week

- [ ] Did anyone still ask "where is it?" in chat — the real success metric (PRD §10)
- [ ] Did anything break that no monitor caught
- [ ] Change one week's venue and confirm subscribers' calendars updated
- [ ] Check every free tier still reads $0
- [ ] Write it all in `BUILD-LOG.md`

**Then leave it alone for a month.** Resist adding RSVPs. The non-goals in PRD §4 exist
because a small thing that works is the goal, and the next project is waiting.
