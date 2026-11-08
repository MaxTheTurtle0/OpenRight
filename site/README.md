# OpenRight landing site

Static landing page for [openright.ma2.dev](https://openright.ma2.dev), built with [Astro](https://astro.build) and served as a Cloudflare Worker with static assets. It lives apart from the macOS app; nothing here is part of the Swift build.

All copy (features, shortcuts, requirements) comes from the repository [README](../README.md). Update the site when that changes. The icon artwork is the app icon. `public/` holds web-sized copies: `icon-512.png`, `icon-192.png` and `icon-96.png` for the logo, `favicon.ico` (16/32/48) and `favicon-32.png`, `apple-touch-icon.png` (180), and `og.png` (1200×630) for link previews. Download buttons point at `releases/latest/download/OpenRight.dmg`, so new releases need no site change.

## Run locally

Requires Node 18.20+.

```sh
cd site
npm install
npm run dev        # http://localhost:4321, also bound to the LAN/tailnet
npm run build      # static output in dist/
npm run preview    # serve dist/
```

## Deploy

`wrangler.jsonc` defines the Worker `site-openright`, which serves `dist/` and is attached to the custom domain `openright.ma2.dev` (Cloudflare manages that DNS record).

```sh
cd site
export CLOUDFLARE_API_TOKEN=...   # token with Workers Scripts + Workers Routes/Custom Domains edit
export CLOUDFLARE_ACCOUNT_ID=...
npm run deploy                    # astro build && wrangler deploy
```

Verify with `curl -I https://openright.ma2.dev`.
