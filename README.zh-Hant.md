# catussh

[English](./README.md) · [简体中文](./README.zh-Hans.md) · **繁體中文**

專為管理 Linux 伺服器打造的原生 macOS App：以 [Ghostty](https://ghostty.org) 為基礎的 SSH
終端機、SFTP 檔案傳輸、即時資源監控，每台伺服器三者並排可用。

[![License](https://img.shields.io/badge/license-MIT%20(Lakr's%20Edition)-blue)](./LICENSE)
![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey)
![Swift](https://img.shields.io/badge/Swift-6.2-orange)

> [!NOTE]
> **catussh 是 Rayon 的延續。** 原作者封存 [Lakr233/Rayon](https://github.com/Lakr233/Rayon)
> 之後，Rayon 在本儲存庫 [mizorewww/catussh](https://github.com/mizorewww/catussh) 繼續維護，
> 如今更名為 catussh。本專案與原作者無關，也未獲其背書。App Store 上架的「Rayon」屬於第三方，
> 與這份程式碼無關。

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./Resources/Screenshots/home-dark.jpg">
  <img alt="catussh 首頁：上方是快速連線，下方是已儲存伺服器的卡片，每張卡片都有連線、檔案和監控按鈕。" src="./Resources/Screenshots/home-light.jpg">
</picture>

## 目錄

- [功能](#功能)
- [螢幕截圖](#螢幕截圖)
- [快速開始](#快速開始)
- [使用 catussh](#使用-catussh)
- [安全性](#安全性)
- [取得協助與參與貢獻](#取得協助與參與貢獻)
- [致謝與授權](#致謝與授權)

## 功能

- **每台伺服器都有終端機、檔案和監控。** 一鍵開啟，工具列上的切換器可在同一台伺服器的三個畫面間來回切換。
- **原生 Ghostty 終端機**，透過 [libghostty-spm](https://github.com/Lakr233/libghostty-spm) 整合：
  GPU 繪製，內建 600 多套主題，半透明背景能透出視窗材質。
- **視覺化終端機設定。** 字型直接從 Mac 已安裝的字型中挑選，支援真實的字重樣式、OpenType 特性與可變字型軸；
  快速鍵以按鍵錄製，並以鍵帽形式顯示；每個滑桿都能直接輸入數值。
- **快速連線。** 輸入 `user@host:port` 後按 Return；連線前會把輸入拆成使用者、主機和連接埠讓你確認。
- **伺服器監控**，讀取 Linux `/proc` 檔案系統：CPU、記憶體、磁碟、網路和 NVIDIA GPU，不必安裝任何 agent。
- **身分**：密碼或金鑰皆可，多台伺服器共用。
- **程式碼片段**可在多台伺服器上同時執行，支援**連接埠轉送**，還有帶著奔跑小貓的**選單列**監控。
- **免費且開放原始碼。**

## 螢幕截圖

### 伺服器列表

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./Resources/Screenshots/servers-dark.jpg">
  <img alt="伺服器列表依正式環境、CI 和家用實驗室分組，每一列都有檔案、監控和連線按鈕。" src="./Resources/Screenshots/servers-light.jpg">
</picture>

### 終端機文字設定

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./Resources/Screenshots/text-dark.jpg">
  <img alt="設定中的文字頁：字型選擇器、樣式選單、附數值輸入框的字級滑桿，以及筆畫加粗。" src="./Resources/Screenshots/text-light.jpg">
</picture>

### 配色與即時預覽

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./Resources/Screenshots/colors-dark.jpg">
  <img alt="設定中的配色頁：上方是即時終端機預覽，下方是主題庫。" src="./Resources/Screenshots/colors-light.jpg">
</picture>

### 鍵盤快速鍵

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./Resources/Screenshots/keyboard-dark.jpg">
  <img alt="設定中的鍵盤頁：快速鍵以鍵帽顯示，搭配淺白的動作說明，依用途分組。" src="./Resources/Screenshots/keyboard-light.jpg">
</picture>

螢幕截圖會跟隨 GitHub 的淺色或深色主題。圖中的伺服器位址皆為保留給文件使用的位址。

## 快速開始

目前還沒有預先編譯的安裝檔，需要從原始碼建置。

### 系統需求

- macOS 13 或以上版本
- Xcode 26 或以上版本（Ghostty 相依套件需要 Swift 6.2）。只裝 Command Line Tools 不夠，
  必須安裝完整的 Xcode，並用 `xcode-select` 選取它。

### 建置與安裝

```sh
git clone https://github.com/mizorewww/catussh.git
cd catussh

# Debug 建置 → DerivedData/Build/Products/Debug-maccatalyst/catussh.app
bash Workflow/Scripts/build-macos.sh

# Release 建置，並安裝到 /Applications
bash Workflow/Scripts/install-macos.sh
```

建置產物為通用二進位檔（`arm64` 與 `x86_64`），使用 ad hoc 簽署，只適合在自己的 Mac 上執行，未經公證。
設定 `DERIVED_DATA_PATH` 可以改用其他建置目錄。若要散布 catussh，請設定你自己的團隊、簽署身分和佈建描述檔；
更換簽署身分可能導致無法存取既有的鑰匙圈項目。

也可以開啟 `App.xcworkspace`，執行 **Rayon** scheme（Xcode 專案與模組目前仍沿用 Rayon 這個名稱）。

## 使用 catussh

1. **新增伺服器**：在首頁按 **New Server**（⇧⌘N）。身分維持 *Automatic* 會依序嘗試你的所有身分，也可以手動指定一個。
2. **連線**：按伺服器卡片或 **Connect**。**Files** 開啟 SFTP，**Monitor** 開啟即時用量；工具列切換器可在三者間切換。
3. **快速連線**：在首頁輸入 `user@host`、`user@host:2222` 或完整的 `ssh` 指令，
   會使用設為 *Authenticate automatically* 的身分登入。
4. **一次開啟多個終端機**：**Open Terminals…**（⇧⌘T）。
5. **設定**位於側邊欄左下角（⌘,）：General、Connection，以及終端機相關的 Text、Colors、Cursor、Window、
   Mouse & Clipboard、Keyboard 和 Advanced。Ghostty 設定項目的支援範圍請見
   [Foundation/RayonTerminal/CONFIGURATION.md](Foundation/RayonTerminal/CONFIGURATION.md)。

### iPhone 與 iPad

iOS 版（`mRayon`，iOS 16+）與 Mac 共用 Ghostty 終端機和同一套設定：分類、字型選擇器和快速鍵編輯器都相同，
在 iPhone 和 iPad 上以列表呈現。鍵盤上方是 Ghostty 的按鍵列（esc、tab、可鎖定的 ctrl/alt/cmd、方向鍵、符號、貼上）。
其他畫面仍是舊版 iOS 設計。請用 `App.xcworkspace` 中的 **mRayon** scheme 建置；UI 測試位於
[Application/mRayonUITests](Application/mRayonUITests/README.md)。

## 安全性

以下問題繼承自 Rayon，目前尚未解決。修正之前，請勿用它連線至你承受不起外洩的帳密。

- **未驗證主機金鑰**：`NSRemoteShell.m` 會記錄伺服器指紋，卻從未與受信任的主機金鑰比對，因此連線可能遭受中間人攻擊。

原清單上的另外兩個問題已在 catussh 中修正：帳密儲存從「IV 等於金鑰」的 AES-CBC 改為使用隨機 nonce 的
AES-256-GCM；解密失敗也不會再被誤判為資料遺失而遭覆寫。

若發現新的漏洞，請勿在公開 issue 貼出利用細節，先開一個 issue 索取私下聯絡方式。

## 取得協助與參與貢獻

- Bug 回報與功能建議：[提交 issue](https://github.com/mizorewww/catussh/issues)。
- 歡迎 Pull Request。送出前請執行終端機套件的測試；測試會短暫開啟原生終端機視窗，不會建立 SSH 連線，也不會動到帳密儲存：

  ```sh
  swift test --package-path Foundation/RayonTerminal          # macOS
  cd Foundation/RayonTerminal && xcodebuild test \
    -scheme RayonTerminal-Package -destination "platform=iOS Simulator,name=iPhone 17 Pro"
  ```

App 程式碼位於 `Application/Rayon`（macOS）與 `Application/mRayon`（iOS）；共用程式碼位於 `Foundation/`
（`RayonModule` 負責 SSH、資料與檔案傳輸，`RayonTerminal` 負責 Ghostty 終端機及其設定，
`RayonDesign` 是設計系統，`MachineStatus` 負責監控）。

## 致謝與授權

catussh 由 [@mizorewww](https://github.com/mizorewww) 維護，是 Rayon 的延續。

Rayon 由 [@Lakr233](https://github.com/Lakr233) 建立，參與者還有
[@__oquery](https://twitter.com/__oquery)、[@zlind0](https://github.com/zlind0)、
[@unixzii](https://twitter.com/unixzii)、[@82flex](https://twitter.com/82flex)、
[@xnth97](https://twitter.com/xnth97)、[@misakicoca](https://twitter.com/misakicoca) 和
[@NyaaLyn](https://twitter.com/NyaaLyn)。

終端機採用 [Ghostty](https://github.com/ghostty-org/ghostty)（MIT），透過
[libghostty-spm](https://github.com/Lakr233/libghostty-spm) 整合。第三方授權（包括 libssh2 與 OpenSSL）
請見 [Resources/LICENSE](./Resources/LICENSE)。

catussh 以 [MIT License — Lakr's Edition](./LICENSE) 釋出。圖片素材不授權重複使用。

Copyright © 2022 Lakr Aream. Copyright © 2026 mizorewww and contributors.
