<p align="center">
  <img src="Resources/AppIcon.png" width="128" height="128" alt="RemoteCommander App Icon">
</p>

# RemoteCommander 🚀
### Native macOS Desktop Bridge for ChatGPT Browser Control

[![Platform](https://img.shields.io/badge/Platform-macOS%2014.0%2B-black?style=flat&logo=apple)](https://www.apple.com/macos/)
[![Language](https://img.shields.io/badge/Swift-6.0-orange?style=flat&logo=swift)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**RemoteCommander** is an Apple native macOS application (SwiftUI / AppKit) that enables **ChatGPT running in your web browser** to execute terminal commands on your Mac. It features a desktop interface with **human-in-the-loop interactive approval prompts**, real-time terminal streaming, an execution history audit log, and zero-configuration HTTPS tunneling.

```
       ┌────────────────────────┐
       │   ChatGPT in Browser   │
       │     (chatgpt.com)      │
       └───────────┬────────────┘
                   │ Tool Call / Action (HTTPS + Bearer Token)
                   ▼
       ┌────────────────────────┐
       │ Cloudflare Quick Tunnel│
       │   (trycloudflare.com)  │
       └───────────┬────────────┘
                   │ Encrypted Local Tunnel
                   ▼
┌────────────────────────────────────────────────────────┐
│             RemoteCommander macOS Native App           │
│                                                        │
│  ┌───────────────────────┐   ┌──────────────────────┐  │
│  │ Local HTTP/MCP Server │──▶│ Approval Prompt (UI) │  │
│  └───────────────────────┘   └──────────┬───────────┘  │
│                                         │ Approved?    │
│                                         ▼              │
│  ┌───────────────────────┐   ┌──────────────────────┐  │
│  │  Live Terminal View   │◀──│ Shell Runner (zsh)   │  │
│  └───────────────────────┘   └──────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

---

## 📥 Download

Pre-built standalone application for macOS 14+ (Apple Silicon):

- **[⬇️ Download RemoteCommander.zip (Latest)](https://github.com/faridparsa/Mac-ChatGPT-RemoteCommander/raw/main/RemoteCommander.zip)** *(Direct 1-click download, ~20 MB)*
- You can also clone this repository directly; the pre-compiled **`RemoteCommander.app`** bundle is included right in the project root!

> **Installation**:
> 1. Download and unzip `RemoteCommander.zip` (or use the pre-built `RemoteCommander.app` in the cloned repo).
> 2. Drag **RemoteCommander.app** into your `/Applications` folder.
> 3. Double-click to launch!

---

## ✨ Features

- 🛡️ **Interactive Command Approval (Human-in-the-Loop)**:
  - Every command requested by ChatGPT is paused and queued for your confirmation.
  - The app presents a review card with the exact command, working directory, and risk classification:
    - 🟢 **Safe**: Read-only inspection (`ls`, `cat`, `pwd`, `git status`, `sw_vers`, `date`)
    - 🟡 **Moderate**: File modifications and builds (`mkdir`, `touch`, `cp`, `git commit`, `npm`, `swift`)
    - 🔴 **High Risk**: Destructive commands (`rm -rf`, `sudo`, `dd`, `kill -9`, piping to bash)
  - Choose **[ Approve & Run ]** or **[ Reject ]** with one click or keyboard shortcut.

- 🖥️ **Native Windowed macOS Interface (SwiftUI)**:
  - **Approvals Tab**: Live review queue with risk tags, working directory details, and approval actions.
  - **Terminal Console**: Dark monospace terminal with real-time streaming output, auto-scroll, copy, and clear controls.
  - **Execution History**: Searchable audit log of past runs with duration (ms), exit codes, and stdout/stderr inspectors.
  - **ChatGPT Setup**: Displays your active HTTPS Tunnel URL, Security Bearer Token, and a 1-click copyable OpenAPI schema.
  - **Settings & Preferences**: Set custom working directories, shell preference (`/bin/zsh`, `/bin/bash`), timeouts, and optional auto-approval for safe read-only commands.

- 🌐 **Zero-Config Public HTTPS Tunnel (Cloudflare Quick Tunnel)**:
  - Built-in manager for ephemeral Cloudflare Quick Tunnels (`*.trycloudflare.com`).
  - Automatically provisions an encrypted public HTTPS endpoint without requiring an account, domain purchase, or router port forwarding.

- 🔌 **Dual Protocol Support**:
  - **OpenAPI 3.1 REST API** (`/api/execute`): Direct plug-and-play integration with ChatGPT Custom GPT Actions.
  - **Model Context Protocol (MCP)** (`/mcp` and `/sse`): Native support for ChatGPT and AI MCP connectors.

---

## 📋 Prerequisites

- **macOS Sonoma (14.0)** or later (Apple Silicon recommended).
- **Swift 6.0+** / Xcode Command Line Tools (`xcode-select --install`).
- A **ChatGPT** account (ChatGPT Plus, Team, or Enterprise recommended for Custom GPT Actions or MCP connectors).

---

## ⚡ Quick Start

### 1. Clone & Build the Application

```bash
# Clone the repository
git clone https://github.com/faridparsa/Mac-ChatGPT-RemoteCommander.git
cd Mac-ChatGPT-RemoteCommander

# Build and package the native application
./scripts/build.sh
```

The build script compiles the release binary, auto-provisions the required tunnel helper, and packages everything into a standalone `RemoteCommander.app`.

### 2. Launch RemoteCommander

```bash
open RemoteCommander.app
```

*(You can also move `RemoteCommander.app` into your `/Applications` folder for everyday access).*

---

## 🔗 Connecting to ChatGPT in Your Browser

Connecting RemoteCommander to your web ChatGPT session takes less than one minute:

### Step 1: Retrieve Your Live Endpoint & Token
1. Open **RemoteCommander**.
2. Click the **ChatGPT Setup** tab in the sidebar.
3. If the tunnel is stopped, click **Start Cloudflare Tunnel**.
4. Copy your **Public HTTPS Endpoint** (e.g. `https://random-subdomain.trycloudflare.com`) and your **Security Bearer Token**.

### Step 2: Create a Custom GPT Action
1. Open [chatgpt.com](https://chatgpt.com) in your web browser.
2. Go to **Explore GPTs** -> click **+ Create** (top right) -> select the **Configure** tab.
3. Scroll down and click **Create new action**.
4. Configure **Authentication**:
   - **Authentication Type**: `API Key`
   - **Auth Type**: `Bearer`
   - **API Key**: Paste your **Security Bearer Token** from RemoteCommander.
5. Configure **Schema**:
   - In RemoteCommander, click **Copy OpenAPI 3.1 Schema**.
   - Paste it into the Schema box in ChatGPT.
6. Save your Custom GPT.

### Step 3: Test Execution
In your ChatGPT conversation, simply say:
> *"Check my macOS version and list the files in my current directory."*

ChatGPT will invoke `executeCommand`. An approval prompt will immediately pop up in **RemoteCommander** on your Mac. Click **[ Approve & Run ]** and the output will stream directly back to your ChatGPT chat!

---

## 🔒 Security Architecture

| Security Layer | Description |
| :--- | :--- |
| **Human-in-the-Loop** | Every command halts execution asynchronously until explicitly approved in the native Mac UI. |
| **Bearer Token Auth** | All incoming HTTP and MCP requests require an `Authorization: Bearer <token>` header matching the app's secret token. |
| **Risk Detection** | Commands are automatically analyzed against pattern signatures for destructive flags (`rm -rf`, `sudo`, `dd`). |
| **Unprivileged Execution** | Commands execute strictly within standard user privileges—never as `root`. |
| **Audit Trail** | Full audit log recording timestamps, commands, working directories, execution duration, and exit codes. |

---

## 📂 Project Structure

```
Mac-ChatGPT-RemoteCommander/
├── Package.swift                    # Swift Package Manager manifest
├── README.md                        # Documentation & setup guide
├── LICENSE                          # MIT License
├── scripts/
│   └── build.sh                     # Release build & app bundle assembler
└── Sources/RemoteCommander/
    ├── RemoteCommanderApp.swift     # SwiftUI @main entry point & menu items
    ├── Models/
    │   ├── CommandRequest.swift     # Request data model & lifecycle states
    │   ├── ExecutionRecord.swift    # Execution history and timing record
    │   ├── RiskAssessment.swift     # Command risk analyzer (Safe / Moderate / High Risk)
    │   ├── AppSettings.swift        # User preferences & security token manager
    │   └── UIState.swift            # View state coordinator
    ├── Services/
    │   ├── ProcessRunner.swift      # Async shell execution with stdout/stderr capture
    │   ├── HTTPServer.swift         # Zero-dependency Apple Network.framework HTTP & MCP server
    │   ├── TunnelManager.swift      # Cloudflare Quick Tunnel process manager
    │   └── CommandManager.swift     # Approval queue and execution controller
    └── Views/
        ├── ContentView.swift        # Main NavigationSplitView and banner alerts
        ├── ApprovalsView.swift      # Interactive approval card with risk badge
        ├── TerminalView.swift       # Monospace dark terminal console viewer
        ├── HistoryView.swift        # Searchable execution history & output drawer
        ├── TunnelSetupView.swift    # Live tunnel status, token, & ChatGPT setup guide
        └── SettingsView.swift       # Preferences & folder picker
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
