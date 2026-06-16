# Upstream AI · Preview Framework

One HTML template, N JSON files. Each pilot district = one JSON file.

## Files

```
preview.html        # single template (HTML + CSS + JS render layer)
data/
  alma.json         # Town of Alma, CO
  genesee.json      # Genesee Water & Sanitation District, CO
```

## URLs

```
preview.html?district=alma
preview.html?district=genesee
```

If no `?district=` param is given, **alma** loads by default.

## Adding a new district

1. Copy `data/alma.json` → `data/<newdistrict>.json`
2. Edit values (district name, operator, samples, calendar events, MOR rows, daily-log
   defaults, trend metrics, chart polyline/markers, documents, chat preset Q/A).
3. Make sure every `openId` in `calendar.days[].events[]` and `samples[]` has a
   matching key in `events`. Every `report.openTarget` is either `view:<name>`
   (jumps to a view) or an `events[]` key (opens the modal).
4. Open `preview.html?district=<newdistrict>`. Done — no build step.

## JSON schema (top-level keys)

| Key | Purpose |
|---|---|
| `meta` | Page title, gate access codes, confidential badge text |
| `district` | Display name, location, tagline |
| `operator` | Name, role, initials, badge |
| `today` | Topbar text, sidebar sync indicator |
| `topbarPull` | Thursday pull pill: aria, label, count |
| `compliance` | Page sub, hero title/sub/stats, pull-banner, comingUp |
| `reports` | Active reports list (March MOR, CCR, etc.) |
| `tasks` | This week's tasks |
| `submitted` | Recently submitted list |
| `calendar` | monthLabel + days[35] each `{num, outside?, today?, events[]}` |
| `samples` | Upcoming lab samples |
| `mor` | Title, sub, draft banner, rows[], callout, ORC block, submit note |
| `dailyLog` | sections[] each with `fields[]` |
| `trends` | metrics[], leftChart, rightChart (SVG via polyline/markers/thresholds) |
| `documents` | facility[] + global[] |
| `chat` | greeting, presetQ/presetA/presetCite |
| `events` | Map keyed by `openId` → full modal payload |

## Render mechanism (no framework, no build)

The template uses three custom attributes that the render layer (`renderAll()` in
`preview.html`) processes on load:

- `data-field="path.to.value"` — read string from JSON, set `innerHTML`.
  Example: `<div data-field="district.name">District</div>`.
- `data-field-aria="path"` — same but sets `aria-label`.
- `data-cls-field="path"` — adds the resolved string as a class to the element
  (used for status tag colors).

For collections (reports, tasks, samples, calendar days, MOR rows, daily-log
fields, trend metrics, documents, etc.), dedicated `render*()` functions in the
script block build the markup from the JSON arrays.

## Static hosting

Pure static. Drop `preview.html` + `data/` at the repo root and GitHub Pages
serves it. No build, no Node, no dependencies.

If serving from `file://` (e.g. emailed as a single file), the embedded fallback
`<script type="application/json" id="embeddedDistrict">…</script>` is loaded when
`fetch()` fails. Paste a district's JSON into that tag to ship a single-file
preview by email.

## Access codes

Default codes (all three): `upstream`, `demo`, `preview`. Edit
`meta.accessCodes` in each district's JSON to override.
