# Upstream AI Website — Security & Deployment Notes

## 🚨 CRITICAL: SSL Certificate Fix

The live site at getupstream.ai has a **hostname mismatch SSL error** — the cert is
not valid for "getupstream.ai". This is a hosting configuration issue, not a code issue.

### Fix by host:

**Netlify (most likely if using Netlify):**
1. Go to Site Settings → Domain Management
2. Verify your custom domain is added as the primary domain
3. Click "Verify DNS configuration"
4. Then click "Provision certificate" under HTTPS
5. Wait 2–5 minutes — Netlify auto-provisions Let's Encrypt certs for verified domains

**Vercel:**
1. Go to Project Settings → Domains
2. Remove and re-add getupstream.ai
3. Vercel auto-issues a cert once DNS is verified

**Cause:** Usually the cert was issued for a www. or netlify.app subdomain but traffic
is hitting the apex domain (getupstream.ai), or DNS was pointed before the cert was issued.

---

## Security Headers

Two files are included to set security headers at the hosting layer:

- `_headers` — for Netlify
- `vercel.json` — for Vercel

These add:
- `X-Frame-Options: DENY` — prevents clickjacking
- `X-Content-Type-Options: nosniff` — prevents MIME sniffing
- `X-XSS-Protection` — legacy XSS protection for IE/old browsers  
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy` — blocks camera, mic, geolocation, payment APIs
- `Content-Security-Policy` — restricts resource loading to known-good origins
- `Strict-Transport-Security` — HSTS forces HTTPS (max-age 2 years)

The HTML also includes meta-tag equivalents for the headers that work as meta tags
as a belt-and-suspenders approach for hosts that don't support file-based headers.

---

## Watershed Favicon

`favicon.svg` — the primary icon, a stylized watershed/river network flowing to a basin.

For full browser compatibility, you also need:
- `favicon-32.png` (32×32px, export from favicon.svg)
- `favicon-16.png` (16×16px, optional)  
- `apple-touch-icon.png` (180×180px, export from favicon.svg)

**Quick export with Inkscape or any SVG editor:**
1. Open favicon.svg
2. Export as PNG at 180×180 → save as apple-touch-icon.png
3. Export as PNG at 32×32 → save as favicon-32.png

**Or use a free online tool:** https://realfavicongenerator.net
Upload favicon.svg and download the full favicon package.

---

## SEO & AI Bot Readiness

The HTML head includes:
- Full meta description + keywords
- Open Graph tags (Facebook, LinkedIn, Discord, Slack previews)
- Twitter Card tags
- JSON-LD structured data (Organization, WebSite, WebPage, SoftwareApplication + Offers)
- `robots.txt` — explicitly allows all major AI crawlers (GPTBot, Claude-Web, PerplexityBot, etc.)
- `sitemap.xml` — linked in both robots.txt and the HTML head

---

## Form Setup

Replace `YOUR_FORM_ID` in index.html line ~580 with your Formspree form ID:

```html
<form id="access-form" action="https://formspree.io/f/YOUR_FORM_ID" ...>
```

Get a free ID at https://formspree.io (50 submissions/month free).
If Formspree is not configured, the form gracefully falls back to a mailto: link.

The form also includes:
- Honeypot anti-spam field (hidden, bots fill it in, humans don't)
- Client-side input sanitization before the mailto fallback
- Accessible labels, ARIA roles, keyboard navigation
- Escape key + overlay click to close modal
