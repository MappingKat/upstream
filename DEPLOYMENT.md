# Upstream AI — GitHub Pages Deployment Notes

## Deploy

1. Push repo to GitHub
2. Settings → Pages → Source: `main` branch, `/ (root)`  
3. Add custom domain `getupstream.ai` in Pages settings
4. Enable **Enforce HTTPS**

GitHub auto-provisions an SSL certificate for verified custom domains via Let's Encrypt.
There is no `_headers` or `vercel.json` on GitHub Pages — security headers are in each HTML `<head>`.

## DNS for getupstream.ai

Point your domain registrar to GitHub Pages:

```
A     @    185.199.108.153
A     @    185.199.109.153
A     @    185.199.110.153
A     @    185.199.111.153
CNAME www  <your-github-username>.github.io
```

## SSL

GitHub Pages auto-provisions Let's Encrypt certs once DNS is verified. If the cert shows
as pending, wait 15 minutes after DNS propagates, then re-check Pages settings.

## Security headers

GitHub Pages serves no custom response headers. We use `<meta http-equiv>` equivalents
in every HTML `<head>`. Limitations vs. server headers:
- `X-Frame-Options` cannot be a meta tag — mitigated by `frame-ancestors 'none'` in CSP
- `Strict-Transport-Security` (HSTS) cannot be a meta tag — GitHub Pages enforces HTTPS
  automatically when "Enforce HTTPS" is enabled in Pages settings

## Forms

Formspree handles all form submissions. Endpoints:
- Early Access: `https://formspree.io/f/xaqpdgaj`
- Contact: `https://formspree.io/f/meerlbdr`
- Pilot application: `https://formspree.io/f/xwvrndae`

Free tier: 50 submissions/month. Upgrade at formspree.io if volume exceeds this.

## Spam protection

All forms include:
1. Honeypot field (`name="_gotcha"`, hidden, `tabindex="-1"`)
2. Math CAPTCHA generated at runtime (not static, harder to pre-solve)

Formspree also runs its own spam filtering on the backend.

## .nojekyll

The `.nojekyll` file in the repo root disables GitHub's Jekyll build step. This is
required — without it, Jekyll ignores files/folders starting with `_` and may
reprocess HTML unexpectedly.

## Excluded files

These files are not needed for the live site and can be `.gitignore`'d:
- `vercel.json` — Vercel only
- `_headers` — Netlify only
