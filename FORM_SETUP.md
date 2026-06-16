# Form Setup — Upstream AI

Three Formspree forms handle all contact and lead capture. Endpoints are already live in the code.

## Configured endpoints

| Form | Formspree ID | File |
|---|---|---|
| Early Access | `xaqpdgaj` | `index.html` |
| Contact | `meerlbdr` | `index.html` |
| Pilot Application | `xwvrndae` | `pilot.html` |

Login at https://formspree.io to view submissions, export CSVs, and manage notifications.

## Spam protection (already in place)

Every form has two layers of protection:

**1. Honeypot field**
A hidden `<input name="_gotcha">` that legitimate users never see or fill. Bots that
auto-fill all fields get silently dropped. No user friction.

**2. Math CAPTCHA**
A random addition problem (`What is 4 + 7?`) generated in JavaScript at page load.
Because it's runtime-generated, it can't be pre-solved from static HTML analysis.
Wrong answers show an inline error and regenerate the problem.

**3. Formspree backend filtering**
Formspree runs its own spam detection on every submission as a third layer.

## Changing the email destination

Log into formspree.io and update the destination email per form.
Currently all forms route to hello@getupstream.ai.

## Submission fallback (mailto)

If Formspree is unreachable (network error, rate limit), both forms on `index.html`
fall back to opening the user's email client with all fields pre-populated. This means
submissions never silently fail.

## Upgrading Formspree

Free tier: 50 submissions/month per form.
If volume exceeds this, upgrade to Formspree Basic ($10/month) which also unlocks:
- Auto-responder emails to submitters
- Google Sheets integration
- Spam filtering dashboard

## Testing

1. Open the form on the live site
2. Submit with a real email address
3. Check hello@getupstream.ai within a few minutes
4. Check the Formspree dashboard at formspree.io/forms
