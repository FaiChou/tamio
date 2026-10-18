# tamio.sh

Tamio's website: a static page in `public/`, served by Cloudflare Workers with
static assets. `src/index.js` sends `www.tamio.sh` to `tamio.sh`, turns
`/download` to the latest release, and serves the rest from
`public/`. Headers are in `public/_headers`.

```sh
cd website
npm install
npm run dev       # http://localhost:8787
npm run deploy    # to tamio.sh and www.tamio.sh
```

Deploying needs `wrangler login` to the Cloudflare account that holds the
`tamio.sh` zone. The app icon images come from `Resources/Tamio.icon`.
