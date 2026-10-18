// tamio.sh on Cloudflare Workers: the site is static assets; this Worker
// sends www to the bare domain, turns /download into the latest release's
// disk image, and serves everything else from the assets.

const REPO = "missuo/tamio";
const RELEASES = `https://github.com/${REPO}/releases/latest`;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.hostname === "www.tamio.sh") {
      url.hostname = "tamio.sh";
      return Response.redirect(url.toString(), 301);
    }

    if (url.pathname === "/download" || url.pathname === "/download/") {
      return Response.redirect(await latestDiskImage(), 302);
    }

    return env.ASSETS.fetch(request);
  },
};

/** The latest release's .dmg, or the release page when GitHub cannot say. */
async function latestDiskImage() {
  try {
    const response = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`, {
      headers: { "User-Agent": "tamio.sh", Accept: "application/vnd.github+json" },
      // Asked of GitHub at most every ten minutes.
      cf: { cacheTtl: 600, cacheEverything: true },
    });
    if (!response.ok) return RELEASES;
    const release = await response.json();
    const image = release.assets?.find((asset) => asset.name.endsWith(".dmg"));
    return image?.browser_download_url ?? RELEASES;
  } catch {
    return RELEASES;
  }
}
