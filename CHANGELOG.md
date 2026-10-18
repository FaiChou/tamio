# Changelog

What changes in each version of Tamio. Each release's notes come from its
section here: on the GitHub release, and in the update window that offers it.

Write new entries under **Unreleased**. To release, rename that heading to the
version and date (`## [0.2.0] - 2026-11-02`), set `MARKETING_VERSION` to match,
and tag `v0.2.0`. A tag with no section here is not built.

## [Unreleased]

## [0.1.3] - 2026-10-18

- Agent activity shows a short command whole, and a longer one or a task's
  steps behind a click, never cut off.
- Tamio installs with Homebrew: `brew install --cask owo-network/brew/tamio`.

## [0.1.2] - 2026-10-18

### Sessions

- The Terminal · Files · Monitor switcher is on the Files page too, so Files
  no longer leaves you there.
- The tab bar above the terminal is gone. A server with several terminals lists
  each one under it in the sidebar; right-click a session to duplicate a
  terminal, reconnect or close it. The switcher goes back to the terminal used
  last.
- The built-in editor is removed.

### Files

- A server's pane opens in the home folder of the user Tamio signs in as.
- Hidden files are not listed unless you turn them on, in Settings › General ›
  Files or a pane's Actions menu.

### Home

- A click on a card shows its server at once; the cards no longer stutter as
  the panel opens. The panel names its server on a row of its own.
- Containers and processes show their last reading at once and refresh behind
  it; containers list before their figures arrive.
- Disks leave out container layers, snaps, memory filesystems, Time Machine
  snapshots and the system's own mounts, and show each disk once.

## [0.1.1] - 2026-10-18

The first release of Tamio, an SSH client for the Mac.

### Servers

- **New Server** is a dialog: address, label, group, tags, username and port,
  then a password or an SSH key.
- An empty username signs in as `root`.
- Keys are kept in **Identities**: paste one, load it from a file, or generate an
  Ed25519 key. A private key is never shown again once saved.
- The server list shows each server's group as a badge, with live CPU, memory,
  disk and network.

### Home

- A card for every server with live **CPU**, **MEM** and **DISK**, the operating
  system's logo, and a country flag for labels such as `JP Tokyo`.
- Select a card for its details: overview, processes, containers and agent
  activity.
- Search and New Server sit in the toolbar.

### Files

- Two panes, this Mac and the server, each switchable to any server.
- Drag files between the panes or from Finder to copy them; folders go whole.
- Drag a file from a server to Finder to download it.
- Transfers run in a queue with progress, speed, time left, cancel and retry,
  and a notification tells you when one ends while Tamio is in the background.

### Agents (MCP)

- Claude Code, Codex and other MCP clients can list your servers and their live
  status, and, once you approve, run commands and manage servers, keys, snippets
  and port forwards.
- Agents never see passwords or private keys.
- What agents do is recorded per server, under the server's Activity.
- An agent names the task each step serves ("Install nginx"), and all the steps
  of a task are one entry, with each step and its result under it.
- Settings › MCP filters agent activity by server.
- Approvals can be given once, for an hour, or always, for agents that work
  alone while you are away. Always-allowed agents are listed in Settings › MCP,
  where they can be revoked.
- **Settings › MCP** turns the server on or off and sets up Claude Code, Codex
  and the Tamio skill.

### iCloud sync

- On unless you turn it off, so what agents did on your servers is not lost
  with a Mac.
- Servers, identities, snippets, port forwards and known host keys stay the
  same on all your Macs, end-to-end encrypted under a passphrase only your
  devices know. Tamio makes it and keeps it in iCloud Keychain; Settings shows
  it for a device without iCloud Keychain.
- Agent activity from every Mac is kept together, so agents on one Mac know
  what was done from another.

### App

- Updates itself: a new version shows at the bottom of the sidebar, with its
  release notes in the update window.
- Switching between light and dark is smooth.
- Settings never squeeze a title into a narrow column: a wide control moves
  under its title instead.
- A new icon: a glass terminal window, its prompt followed by an agent's typing
  dots, in front of the servers it works on.
