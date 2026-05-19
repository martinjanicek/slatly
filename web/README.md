# Slatly marketing site

Static landing page for the Slatly watchOS app.

## Stack

- Plain HTML + CSS + vanilla JS, no build step.
- 5 languages (EN, CS, DE, FR, ES) loaded on demand from `i18n/<lang>.json`.
- Animated CSS-only "blind in a window" in the hero, no images required.
- Apple Watch screenshots in `assets/` (copied from `docs/screenshots/`).

## Local preview

Any static server works. From the repo root:

```sh
python3 -m http.server -d web 8000
# open http://localhost:8000
```

## Deploy

GitHub Pages: point a repo's `gh-pages` branch or `/web` subfolder at this directory.

Cloudflare Pages / Netlify / any static host: upload the `web/` folder as-is.

## Editing translations

Each language is a flat JSON dictionary keyed by dotted paths matching `data-i18n` attributes in `index.html`. Add a new language:

1. Copy `i18n/en.json` to `i18n/<lang>.json` and translate values.
2. Add `<lang>` to `SUPPORTED` in `script.js`.
3. Add a `<button data-lang="<lang>">…</button>` entry to the `<ul id="langMenu">` block in `index.html`.

## TODO before launch

- [ ] Replace TestFlight CTA `href="#"` with real public link once the build is invitation-ready.
- [ ] Replace GitHub `href="https://github.com/"` with the real repo URL.
- [ ] Add Open Graph image (`assets/og.png`, 1200×630) and reference it from `<meta property="og:image">`.
- [ ] Optional: add `apple-touch-icon.png` and full favicon set.
