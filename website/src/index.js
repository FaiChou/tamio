// tamio.sh on Cloudflare Workers: the site is static assets; this Worker
// sends www to the bare domain and /download to the latest release, and
// serves everything else from the assets.

const REPO = "missuo/tamio";
const RELEASES = `https://github.com/${REPO}/releases/latest`;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.hostname === "www.tamio.sh") {
      url.hostname = "tamio.sh";
      return Response.redirect(url.toString(), 301);
    }

    // tamio.sh/download goes to the latest release, where the disk image is.
    if (url.pathname === "/download" || url.pathname === "/download/") {
      return Response.redirect(RELEASES, 302);
    }

    return env.ASSETS.fetch(request);
  },
};
