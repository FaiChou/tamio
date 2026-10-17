---
name: tamio
description: Work on the user's SSH servers through Tamio's MCP server — list hosts and their live load, run commands on one or many servers (the user approves, Tamio signs in with its own saved keys), add or change servers, SSH keys, snippets and port forwards, and keep each server's agent activity log. Use whenever a task touches the user's servers, fleets, deploys, updates, or "my hosts".
---

# Tamio

Tamio is the user's SSH client for macOS. Its MCP server (`tamio`) knows every
server the user saved: address, port, user, group, tags, how it signs in, and
its live CPU, memory, disk, load and traffic.

## Set up (once)

Tamio must be running with **Settings › MCP › MCP server** on (it is by default).

- Claude Code: `claude mcp add tamio -- /Applications/Tamio.app/Contents/Resources/tamio-mcp`
- Codex (`~/.codex/config.toml`):
  ```toml
  [mcp_servers.tamio]
  command = "/Applications/Tamio.app/Contents/Resources/tamio-mcp"
  ```
- Any other MCP client: a stdio server whose command is
  `/Applications/Tamio.app/Contents/Resources/tamio-mcp`.

## Rules

1. **Read the server's history first.** Before working on a server, call
   `get_activity` with its name: earlier agents, on any of the user's Macs, may
   have changed it.
2. **Run through Tamio.** Prefer `run_command` (or `run_snippet`) over your own
   `ssh`: Tamio signs in with its saved key or password, checks the host key,
   asks the user, records the run in the server's activity, and returns each
   server's exit code and output. Target many servers at once with
   `{"targets": {"group": "Production"}}`, `{"tag": "web"}` or `{"all": true}`.
3. **Report what you do by other means.** If you change a server with your own
   ssh, scp, rsync or a deploy tool, call `log_activity` for it right after,
   with a one-line `summary`, what changed in `details`, and the `commands` you
   ran. Never put secrets in it.
4. **Secrets only go in.** Tamio never returns passwords, private keys or
   passphrases. To give a server a key, call `add_identity` with
   `generate: true`; it returns the public key — install it in the server's
   `~/.ssh/authorized_keys` (for example with `run_command` on a server you can
   already reach), then `update_host` with `identity`.
5. **Every change is approved by the user.** `run_*`, `add_*`, `update_*`,
   `remove_*`, `start_*`/`stop_*` wait for them. Say what you are about to do
   and why before calling one; if they decline, ask rather than retry.
6. Use `sudo: true` for root commands: it runs `sudo -n`, which fails instead of
   waiting for a password; say so if a server needs one.

## Tools

| Tool | What it does |
|---|---|
| `list_hosts` | Servers (filter by `query`, `group`, `tag`) |
| `get_host` | One server, with live status |
| `get_metrics` | Live CPU, memory, disk, load, network, traffic, OS |
| `export_ssh_config` | `Host` blocks, no keys |
| `run_command` / `run_snippet` | Run on servers; exit code and output per server |
| `add_host` / `update_host` / `remove_host` | Manage servers (`password` is write-only) |
| `list_identities` / `add_identity` / `remove_identity` | SSH keys; public keys only |
| `list_snippets` / `add_snippet` / `update_snippet` / `remove_snippet` | Saved commands |
| `list_port_forwards` / `add_port_forward` / `start_port_forward` / `stop_port_forward` / `remove_port_forward` | Tunnels through a server |
| `get_activity` | What agents did on a server, newest first, from every Mac |
| `log_activity` | Record what you did on servers by other means |

## Example: update every production server

1. `get_activity {"host": "…"}` for a few of them, to see recent changes.
2. `run_command {"targets": {"group": "Production"}, "command": "apt-get update && apt-get -y upgrade", "sudo": true, "timeout": 900}`
3. For servers where `/var/run/reboot-required` exists:
   `run_command {"targets": {"hosts": [...]}, "command": "test -f /var/run/reboot-required && echo REBOOT"}`,
   then ask the user before rebooting.
