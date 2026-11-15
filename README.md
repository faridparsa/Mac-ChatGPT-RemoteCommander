# RemoteCommander 🚀
### Apple Native macOS App for ChatGPT Browser Control

**RemoteCommander** is a native Apple macOS application (SwiftUI / AppKit) that lets you execute terminal commands and manage your Mac directly from **ChatGPT in your web browser**—with a standard macOS windowed interface and **human-in-the-loop interactive approval prompts**.

---

## ✨ Key Features

1. **Interactive Approval Prompts (Human-in-the-Loop)**:
   - Whenever ChatGPT requests to run a shell command, the app displays a review card showing the exact command, working directory, and risk classification.
   - **Risk Assessment**:
     - 🟢 **Safe**: Read-only operations (`ls`, `cat`, `pwd`, `git status`, `sw_vers`, `date`)
     - 🟡 **Moderate**: File creations and build tools (`mkdir`, `touch`, `cp`, `git commit`, `npm`, `swift`)
     - 🔴 **High Risk**: Potentially destructive commands (`rm -rf`, `sudo`, `dd`, `kill -9`, piping to bash)
   - Click **[ Approve & Run ]** to execute or **[ Reject ]** to abort and notify ChatGPT.

2. **Native Windowed macOS Interface (SwiftUI)**:
   - **Approvals Tab**: Live queue of pending requests with detailed parameters and action buttons.
   - **Terminal Console**: Dark monospace console with real-time stdout/stderr streaming, auto-scroll, clear, and copy.
   - **Execution History**: Searchable audit log of all commands with duration, exit code, and stdout/stderr inspectors.
   - **ChatGPT Setup**: Status card showing your live Cloudflare Tunnel URL, API token, and a 1-click copyable OpenAPI schema.
   - **Settings & Security**: Configurable default working directory, shell selection (`/bin/zsh`, `/bin/bash`), timeouts, and optional auto-approval for safe commands.

3. **Zero-Configuration Public HTTPS Tunnel (Cloudflare Quick Tunnel)**:
   - Built-in manager for Cloudflare Quick Tunnels (`trycloudflare.com`).
   - Automatically establishes an encrypted public HTTPS endpoint without requiring any account, domain registration, or router port forwarding.

4. **Dual Protocol Support**:
   - **OpenAPI 3.1 REST API** (`/api/execute`): Direct plug-and-play integration with ChatGPT Custom GPT Actions.
   - **Model Context Protocol (MCP)** (`/mcp` and `/sse`): Native support for ChatGPT and AI MCP connectors.

---

## 🚀 Quick Start

### 1. Launch the Native App
```bash
open /Volumes/es/remoteTerminal/RemoteCommander.app
```
*(Or run `swift run` from the project root).*

### 2. Connect to ChatGPT in Your Web Browser (1 Minute)

1. **Open RemoteCommander**:
   - In the **ChatGPT Setup** tab, ensure the tunnel is active and note your **Public HTTPS Endpoint** (e.g. `https://xxxx.trycloudflare.com`) and **Security Bearer Token**.
2. **Open ChatGPT**:
   - Go to [chatgpt.com](https://chatgpt.com) in your browser.
   - Click **Explore GPTs** -> **+ Create** (top right).
3. **Add Action**:
   - Go to the **Configure** tab, scroll down, and click **Create new action**.
   - Under **Authentication**:
     - Authentication Type: `API Key`
     - Auth Type: `Bearer`
     - API Key: Paste your **Security Bearer Token** from RemoteCommander.
   - Under **Schema**:
     - In RemoteCommander, click **Copy OpenAPI 3.1 Schema**.
     - Paste it into the Schema box in ChatGPT.
4. **Test it!**:
   - In your ChatGPT preview or saved GPT, ask:
     > *"Check my macOS version and list files in my workspace."*
   - ChatGPT will call `executeCommand`.
   - An approval prompt will appear in **RemoteCommander** on your Mac.
   - Click **[ Approve & Run ]** and watch the output stream live to ChatGPT!

---

## 🛠️ Project Structure

```
remoteTerminal/
├── RemoteCommander.app/             # Self-contained native macOS app bundle
│   └── Contents/
│       ├── MacOS/RemoteCommander    # Compiled native ARM64 Swift binary
│       ├── Resources/cloudflared   # Bundled Cloudflare Quick Tunnel binary
│       └── Info.plist              # Bundle metadata
├── Sources/RemoteCommander/
│   ├── RemoteCommanderApp.swift     # SwiftUI @main entry point & menu items
│   ├── Models/
│   │   ├── CommandRequest.swift     # Request model and lifecycle status
│   │   ├── ExecutionRecord.swift    # Execution history and timing record
│   │   ├── RiskAssessment.swift     # Command risk classifier & pattern detector
│   │   ├── AppSettings.swift        # User preferences & API key manager
│   │   └── UIState.swift            # View state coordinator
│   ├── Services/
│   │   ├── ProcessRunner.swift      # Async Process execution with stdout/stderr capture
│   │   ├── HTTPServer.swift         # Zero-dependency Apple Network.framework HTTP & MCP server
│   │   ├── TunnelManager.swift      # Cloudflare Quick Tunnel process manager
│   │   └── CommandManager.swift     # Central approval queue and execution controller
│   └── Views/
│       ├── ContentView.swift        # Main NavigationSplitView and banner alerts
│       ├── ApprovalsView.swift      # Pending approval card with risk badge
│       ├── TerminalView.swift       # Monospace dark terminal console viewer
│       ├── HistoryView.swift        # Searchable execution history & detail inspector
│       ├── TunnelSetupView.swift    # Live tunnel status, token, and ChatGPT guide
│       └── SettingsView.swift       # Preferences & directory picker
├── bin/
│   └── cloudflared                  # Standalone Cloudflare Tunnel binary
├── scripts/
│   └── build.sh                     # Automated build and bundle packaging script
└── Package.swift                    # Swift Package Manager manifest
```

---

## 🔒 Security Architecture

- **Token Authentication**: All requests to `/api/execute` and `/mcp` require an `Authorization: Bearer <token>` header matching the app's secret token.
- **Local Isolation**: Commands execute under your standard macOS user permissions without root privileges.
- **Approval Gate**: Commands are held in an asynchronous suspension until explicitly approved via the native UI.
- **Audit Logging**: Every command, exit code, timestamp, and duration is logged locally in the app's history.
