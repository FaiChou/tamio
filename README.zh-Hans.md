# catussh

[English](./README.md) · **简体中文** · [繁體中文](./README.zh-Hant.md)

为管理 Linux 服务器而生的原生 macOS 应用：基于 [Ghostty](https://ghostty.org) 的 SSH
终端、SFTP 文件传输、实时资源监控，每台服务器三者并排可用。

[![License](https://img.shields.io/badge/license-MIT%20(Lakr's%20Edition)-blue)](./LICENSE)
![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey)
![Swift](https://img.shields.io/badge/Swift-6.2-orange)

> [!NOTE]
> **catussh 是 Rayon 的延续。** 原作者归档 [Lakr233/Rayon](https://github.com/Lakr233/Rayon)
> 之后，Rayon 在本仓库 [mizorewww/catussh](https://github.com/mizorewww/catussh) 继续维护，
> 如今改名为 catussh。本项目与原作者无关，也未获其背书。App Store 上架的“Rayon”属于第三方，
> 与这份代码无关。

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./Resources/Screenshots/home-dark.jpg">
  <img alt="catussh 主页：顶部是快速连接，下方是已保存服务器的卡片，每张卡片都有连接、文件和监控按钮。" src="./Resources/Screenshots/home-light.jpg">
</picture>

## 目录

- [功能](#功能)
- [截图](#截图)
- [快速开始](#快速开始)
- [使用 catussh](#使用-catussh)
- [安全](#安全)
- [获取帮助与参与贡献](#获取帮助与参与贡献)
- [致谢与许可证](#致谢与许可证)

## 功能

- **每台服务器都有终端、文件和监控。** 一键打开，工具栏里的切换器可在同一台服务器的三个视图间来回切换。
- **原生 Ghostty 终端**，通过 [libghostty-spm](https://github.com/Lakr233/libghostty-spm) 接入：
  GPU 渲染，内置 600 多套主题，半透明背景能透出窗口材质。
- **可视化终端设置。** 字体直接从 Mac 已安装的字体中挑选，支持真实字重样式、OpenType 特性和可变字体轴；
  快捷键靠按键录制，以键帽形式显示；所有滑块都能直接输入数值。
- **快速连接。** 输入 `user@host:port` 后回车；连接前会把输入拆成用户、主机和端口给你确认。
- **服务器监控**，读取 Linux `/proc` 文件系统：CPU、内存、磁盘、网络和 NVIDIA GPU，无需安装任何 agent。
- **身份**：密码或密钥均可，多台服务器共用。
- **代码片段**可在多台服务器上同时执行，支持**端口转发**，还有带奔跑小猫的**菜单栏**监控。
- **免费开源。**

## 截图

### 服务器列表

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./Resources/Screenshots/servers-dark.jpg">
  <img alt="服务器列表按生产、CI 和家庭实验室分组，每一行都有文件、监控和连接按钮。" src="./Resources/Screenshots/servers-light.jpg">
</picture>

### 终端文字设置

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./Resources/Screenshots/text-dark.jpg">
  <img alt="设置中的文字页：字体选择器、样式菜单、带数值输入框的字号滑块，以及笔画加粗。" src="./Resources/Screenshots/text-light.jpg">
</picture>

### 配色与实时预览

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./Resources/Screenshots/colors-dark.jpg">
  <img alt="设置中的配色页：上方是实时终端预览，下方是主题库。" src="./Resources/Screenshots/colors-light.jpg">
</picture>

### 键盘快捷键

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./Resources/Screenshots/keyboard-dark.jpg">
  <img alt="设置中的键盘页：快捷键以键帽显示，配有直白的动作说明，按用途分组。" src="./Resources/Screenshots/keyboard-light.jpg">
</picture>

截图会跟随 GitHub 的浅色或深色主题。图中的服务器地址均为保留的文档专用地址。

## 快速开始

目前还没有预编译安装包，需要从源码构建。

### 环境要求

- macOS 13 或更高版本
- Xcode 26 或更高版本（Ghostty 依赖需要 Swift 6.2）。只装 Command Line Tools 不够，
  要安装完整的 Xcode，并用 `xcode-select` 选中它。

### 构建与安装

```sh
git clone https://github.com/mizorewww/catussh.git
cd catussh

# Debug 构建 → DerivedData/Build/Products/Debug-maccatalyst/catussh.app
bash Workflow/Scripts/build-macos.sh

# Release 构建，并安装到 /Applications
bash Workflow/Scripts/install-macos.sh
```

构建产物是通用二进制（`arm64` 和 `x86_64`），使用 ad hoc 签名，只适合在自己的 Mac 上运行，没有经过公证。
设置 `DERIVED_DATA_PATH` 可以换一个构建目录。如果要分发 catussh，请配置你自己的团队、签名身份和描述文件；
更换签名身份可能导致无法访问已有的钥匙串条目。

也可以打开 `App.xcworkspace`，运行 **Rayon** scheme（Xcode 工程和模块目前仍沿用 Rayon 这个名字）。

## 使用 catussh

1. **添加服务器**：在主页点 **New Server**（⇧⌘N）。身份保持 *Automatic* 会依次尝试你的所有身份，也可以手动指定一个。
2. **连接**：点服务器卡片或 **Connect**。**Files** 打开 SFTP，**Monitor** 打开实时用量；工具栏切换器可在三者间切换。
3. **快速连接**：在主页输入 `user@host`、`user@host:2222` 或完整的 `ssh` 命令，
   会使用设为 *Authenticate automatically* 的身份登录。
4. **一次打开多个终端**：**Open Terminals…**（⇧⌘T）。
5. **设置**在侧边栏左下角（⌘,）：General、Connection，以及终端相关的 Text、Colors、Cursor、Window、
   Mouse & Clipboard、Keyboard 和 Advanced。Ghostty 配置项的覆盖情况见
   [Foundation/RayonTerminal/CONFIGURATION.md](Foundation/RayonTerminal/CONFIGURATION.md)。

### iPhone 与 iPad

iOS 版（`mRayon`，iOS 16+）与 Mac 共用 Ghostty 终端和同一套设置：分类、字体选择器和快捷键编辑器都一样，
在 iPhone 和 iPad 上以列表呈现。键盘上方是 Ghostty 的按键栏（esc、tab、可锁定的 ctrl/alt/cmd、方向键、符号、粘贴）。
其他页面仍是旧版 iOS 设计。用 `App.xcworkspace` 中的 **mRayon** scheme 构建；UI 测试位于
[Application/mRayonUITests](Application/mRayonUITests/README.md)。

## 安全

下面这个问题是从 Rayon 继承来的，尚未解决。修复之前，请不要用它连接你输不起的凭据。

- **不校验主机密钥**：`NSRemoteShell.m` 会记录服务器指纹，但从不与受信任的主机密钥比对，因此连接可能遭受中间人攻击。

原清单上的另外两个问题已在 catussh 中修复：凭据存储从“IV 等于密钥”的 AES-CBC 改为使用随机 nonce 的
AES-256-GCM；解密失败也不会再被误判为数据缺失而遭覆盖。

如果发现新的漏洞，请不要在公开 issue 中贴出利用细节，先开一个 issue 索要私下联系方式。

## 获取帮助与参与贡献

- Bug 和功能建议：[提交 issue](https://github.com/mizorewww/catussh/issues)。
- 欢迎 Pull Request。提交前请运行终端包的测试；测试会短暂弹出原生终端窗口，不会建立 SSH 连接，也不会碰凭据存储：

  ```sh
  swift test --package-path Foundation/RayonTerminal          # macOS
  cd Foundation/RayonTerminal && xcodebuild test \
    -scheme RayonTerminal-Package -destination "platform=iOS Simulator,name=iPhone 17 Pro"
  ```

应用代码在 `Application/Rayon`（macOS）和 `Application/mRayon`（iOS）；共享代码在 `Foundation/`
（`RayonModule` 负责 SSH、数据和文件传输，`RayonTerminal` 负责 Ghostty 终端及其设置，
`RayonDesign` 是设计系统，`MachineStatus` 负责监控）。

## 致谢与许可证

catussh 由 [@mizorewww](https://github.com/mizorewww) 维护，是 Rayon 的延续。

Rayon 由 [@Lakr233](https://github.com/Lakr233) 创建，参与者还有
[@__oquery](https://twitter.com/__oquery)、[@zlind0](https://github.com/zlind0)、
[@unixzii](https://twitter.com/unixzii)、[@82flex](https://twitter.com/82flex)、
[@xnth97](https://twitter.com/xnth97)、[@misakicoca](https://twitter.com/misakicoca) 和
[@NyaaLyn](https://twitter.com/NyaaLyn)。

终端基于 [Ghostty](https://github.com/ghostty-org/ghostty)（MIT），通过
[libghostty-spm](https://github.com/Lakr233/libghostty-spm) 接入。第三方许可证（包括 libssh2 和 OpenSSL）
见 [Resources/LICENSE](./Resources/LICENSE)。

catussh 以 [MIT License — Lakr's Edition](./LICENSE) 发布。图片素材不授权复用。

Copyright © 2022 Lakr Aream. Copyright © 2026 mizorewww and contributors.
