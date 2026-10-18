# AGENTS.md

Guidance for coding agents (Claude Code, Codex, and the like) working in this
repository. Read it before changing anything; `DESIGN.md` has the product plan.

## What this is

Tamio is a native SSH client for macOS: a Ghostty terminal, dual-pane SFTP,
live status for every server, end-to-end encrypted iCloud sync, and an MCP
server that lets AI agents work on the user's servers with their approval.
It is a Mac Catalyst app (SwiftUI, Swift 6) with an AppKit plugin, macOS 14 or
later, bundle id `sb.moe.tamio`. An iOS app is planned but not started; leave
`Application/TamioMobile` alone unless asked.

## Layout

| Path | What is there |
|---|---|
| `Application/Tamio` | The Mac app. `Interface/` holds the pages (Home, Servers, Files, Settings…), `Bridge/` the AppKit plugin (`MacBridge.bundle`: windows, dialogs, Sparkle), `project.yml` the XcodeGen spec |
| `Foundation/TamioModule` | The app's core: store, sync, SFTP browsing and transfers, the MCP server (`Agent/`) |
| `Foundation/TamioDesign` | Design tokens and shared controls (colours, rows, `RXRowLayout`) |
| `Foundation/TamioTerminal` | The Ghostty terminal and its settings catalog |
| `Foundation/MachineStatus`, `MachineStatusView` | Reading a server's status over SSH, and its cards |
| `External/` | Vendored NSRemoteShell (libssh2), CodeMirrorUI; Sparkle is fetched into `External/Sparkle` by `Workflow/Scripts/sparkle.sh` |
| `Resources/Tamio.icon` | The app icon (Icon Composer) |
| `skills/tamio` | The skill agents install to use Tamio's MCP server |
| `website/` | tamio.sh, a static site on Cloudflare Workers |
| `Workflow/Scripts` | Build, release, appcast and signing scripts |

## Build and test

```sh
bash Workflow/Scripts/build-macos.sh                      # Debug build, signed ad hoc
cd Application/Tamio && xcodegen generate                 # after editing project.yml
swift test --package-path Foundation/TamioModule
swift test --package-path Foundation/MachineStatus
swift test --package-path Foundation/TamioTerminal
bash Workflow/Scripts/fmt.sh                              # swiftformat, Swift 6
```

- **Never sign locally.** Local builds are ad hoc. Developer ID signing,
  notarization and Sparkle signing happen only in GitHub Actions.
- **Never drive or quit the user's own Tamio.** To test the UI, build a copy
  with its own bundle id (for example `sb.moe.tamio.uitest`) and use that.
- Run the module tests after changing `Foundation/`; build the app after
  changing `Application/`.

## Releasing

1. Put the changes under `## [Unreleased]` in `CHANGELOG.md` as you make them,
   in the Keep a Changelog shape: `### Added`, `### Changed`, `### Fixed`,
   `### Removed`, each item a bullet that opens with a bold phrase saying what
   changed for the user, then the detail. Never group by area of the app.
2. To release, add `## [x.y.z] - YYYY-MM-DD` under Unreleased, set
   `MARKETING_VERSION` in `Application/Tamio/project.yml`, run `xcodegen
   generate`, commit, and push the tag `vx.y.z`.
3. `.github/workflows/release.yml` builds, signs, notarizes, writes the
   Sparkle appcast and publishes the release as the latest, with that
   changelog section as its notes. A tag with no section is not built.
4. Check the published DMG: Gatekeeper accepts it, the app carries the iCloud
   entitlements, and the appcast's EdDSA signature verifies.

The Homebrew cask lives in `OwO-Network/homebrew-brew` (`Casks/tamio.rb`); its
scheduled script bumps the version and checksum.

## The website

`website/public` is served by `website/src/index.js` on Cloudflare Workers.
`npm run dev` in `website/` previews it at http://localhost:8787 and `npm run
deploy` publishes it to tamio.sh. The window on the page is drawn by
`public/demo.js` and `demo.css` to the app's own measurements and colours
(`Foundation/TamioDesign/Sources/TamioDesign/Tokens.swift`): keep the two in
step, and never put screenshots of the app on the site.

## Rules of the house

- **Commits:** Conventional Commits (`feat(sync): …`, `fix(ui): …`), imperative,
  a body that says why. No `Co-Authored-By` trailers.
- **Secrets:** never print or commit passwords, private keys, `.p8`/`.p12`
  files or tokens. The MCP server never returns a password, private key or
  passphrase, and nothing should change that.
- **Text is never cut off.** No ellipsis truncation in the UI: show text whole
  (wrap it) or leave it out and put it in a tooltip. Settings rows use
  `RXRowLayout`, which moves a wide control under its label.
- **Agents' history:** every action an agent takes through MCP is recorded per
  server, grouped by the `task` the agent names. Keep new tools recording
  their actions the same way.
- **Comments and copy:** plain, specific English; comments say why, not what.
  Match the surrounding code's style and density.
- **Upstream:** Tamio descends from mizorewww/catussh and Lakr233/Rayon;
  `Workflow/Scripts/tamio-rename.py` ports upstream changes.
