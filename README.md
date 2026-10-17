# Tamio

A native SSH client for macOS: a Ghostty terminal, a dual-pane SFTP browser,
live status for every server, end-to-end encrypted iCloud sync, and an MCP
server so AI agents can work across your hosts with your approval.

Tamio is in early development. The plan is in [design.md](./design.md).

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)
![Swift](https://img.shields.io/badge/Swift-6.2-orange)
[![License](https://img.shields.io/badge/license-MIT-blue)](./LICENSE)

## Build from source

Needs Xcode 26 or later.

```sh
git clone https://github.com/missuo/tamio.git
cd tamio
bash Workflow/Scripts/build-macos.sh          # Debug, signed ad hoc
```

Or open `App.xcworkspace` and run the **Tamio** scheme. After editing
`Application/Tamio/project.yml`, run `xcodegen generate` in `Application/Tamio`.

Tests:

```sh
swift test --package-path Foundation/TamioModule
swift test --package-path Foundation/TamioTerminal
swift test --package-path Foundation/MachineStatus
```

Releases are signed and notarized by GitHub Actions when a `v<version>` tag is
pushed (`.github/workflows/release.yml`).

## Credits

Tamio is based on [catussh](https://github.com/mizorewww/catussh) by mizorewww
(via [missuo/Rayon](https://github.com/missuo/Rayon)), itself a fork of
[Rayon](https://github.com/Lakr233/Rayon) by Lakr Aream. It is not affiliated with
or endorsed by them. Upstream fixes are ported with
`Workflow/Scripts/tamio-rename.py`.

## License

[MIT](./LICENSE). Third-party licenses are listed in [Resources/LICENSE](./Resources/LICENSE).
