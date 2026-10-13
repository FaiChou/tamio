# XMLCoder

Vendored copy of [MaxDesiatov/XMLCoder](https://github.com/MaxDesiatov/XMLCoder),
used by MachineStatus to parse the XML output of `nvidia-smi -q -x`.

Only the decoder is exercised by this project. See the upstream repository for
documentation.

## Fork base

- Upstream: <https://github.com/MaxDesiatov/XMLCoder>
- Tag: `0.13.1` (commit `f30119af03996939cc4f54e0bf0dda9f88a84da5`)

## Local changes

None. The sources are functionally identical to upstream 0.13.1; the only
divergence is a whole-tree formatter pass applied at vendoring time, so diffs
against upstream are noisy but free of behavioral changes.

`Package.swift` intentionally stays at swift-tools-version 5.1 so the library
compiles in the Swift 5 language mode exactly like upstream. Bumping the tools
version pulls the sources into a stricter language mode and re-introduces the
concurrency annotations (`nonisolated(unsafe)`, `Sendable`) that upstream does
not carry; keep local sources patch-free instead.
