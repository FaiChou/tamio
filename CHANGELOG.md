# Changelog

What changes in each version of Tamio. Each release's notes come from its
section here: on the GitHub release, and in the update window that offers it.

Write new entries under **Unreleased**. To release, rename that heading to the
version and date (`## [0.2.0] - 2026-11-02`), set `MARKETING_VERSION` to match,
and tag `v0.2.0`. A tag with no section here is not built.

## [Unreleased]

## [0.1.0] - 2026-10-17

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
- Transfers run in a queue with progress, speed, time left, cancel and retry.

### Agents (MCP)

- Claude Code, Codex and other MCP clients can list your servers and their live
  status, and, once you approve, run commands and manage servers, keys, snippets
  and port forwards.
- Agents never see passwords or private keys.
- What agents do is recorded per server, under the server's Activity.
- **Settings › MCP** turns the server on or off and sets up Claude Code, Codex
  and the Tamio skill.

### App

- Updates itself: a new version shows at the bottom of the sidebar.
- A new icon.
