# Upstream AI — getupstream.ai

Static marketing site for Upstream AI. Deploys to GitHub Pages.

## Deploy to GitHub Pages

1. Push this repo to GitHub
2. Go to **Settings → Pages**
3. Set source to: `Deploy from a branch` → `main` → `/ (root)`
4. Your site publishes at `https://<username>.github.io/<repo>` or your custom domain

### Custom domain (getupstream.ai)
1. Add a `CNAME` file containing `getupstream.ai` (already included)
2. In your DNS provider, add:
   - `A` records pointing to GitHub Pages IPs: `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`
   - Or a `CNAME` record: `www` → `<username>.github.io`
3. In repo Settings → Pages, enter `getupstream.ai` and enable **Enforce HTTPS**

## Forms

Both forms submit to Formspree (already configured):
- Early Access form: `https://formspree.io/f/xaqpdgaj`
- Contact form: `https://formspree.io/f/meerlbdr`
- Pilot application: `https://formspree.io/f/xwvrndae`

If a Formspree submission fails, both forms fall back to opening the user's mail client.

## Spam protection

Each form has two layers:
1. **Honeypot field** — hidden input that bots fill in; real users skip it
2. **Math CAPTCHA** — randomly generated addition problem rendered at runtime

## Analytics

PostHog is configured for pageview tracking, form funnel analysis, and scroll depth.
The API key (`phc_ubeQWz4wP6cJf0AHoM5347Ve3dDjddR8O4i8tBTTBAT`) is public-safe — PostHog
keys are designed to be client-side and project-scoped.

## Security headers

GitHub Pages does not support server-side response headers. Security headers are
applied as `<meta http-equiv>` tags in each page's `<head>`:
- `Content-Security-Policy`
- `X-Content-Type-Options`
- `Referrer-Policy`
- `Permissions-Policy`

Note: `X-Frame-Options` cannot be set via meta tag — the CSP `frame-ancestors 'none'`
directive covers the same protection in modern browsers.

## File structure

```
index.html                    Homepage
for-operators.html            Operator persona page
for-managers.html             Manager persona page
for-boards.html               Board member persona page
case-study-crestone.html      Case study
case-study-round-mountain.html Case study
about.html                    About page
security.html                 Security overview
careers.html                  Careers
epa-finder.html               EPA Grant Finder tool
facts.html                    Facts / stats page
pilot.html                    Pilot application form
preview.html                  Internal dashboard preview (password-gated)
sitemap.xml                   XML sitemap
robots.txt                    Crawler directives
.nojekyll                     Disables Jekyll on GitHub Pages
CNAME                         Custom domain for GitHub Pages
```

## Contact

hello@getupstream.ai
