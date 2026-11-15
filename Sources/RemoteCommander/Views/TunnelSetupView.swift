import SwiftUI

struct TunnelSetupView: View {
    @ObservedObject var tunnelManager: TunnelManager
    @ObservedObject var settings: AppSettings
    @ObservedObject var uiState: UIState
    
    var effectiveUrl: String {
        return tunnelManager.publicUrl ?? "https://<your-tunnel-subdomain>.trycloudflare.com"
    }
    
    var openApiSchema: String {
        let serverUrl = tunnelManager.publicUrl ?? "https://<your-tunnel-url>.trycloudflare.com"
        return """
        {
          "openapi": "3.1.0",
          "info": {
            "title": "RemoteCommander Mac Terminal",
            "description": "Execute shell commands on your Mac directly from ChatGPT with native approval prompts.",
            "version": "1.0.0"
          },
          "servers": [
            {
              "url": "\(serverUrl)"
            }
          ],
          "paths": {
            "/api/execute": {
              "post": {
                "summary": "Run a shell command on Mac terminal",
                "description": "Executes a command on the user's Mac after user approval in the native app.",
                "operationId": "executeCommand",
                "requestBody": {
                  "required": true,
                  "content": {
                    "application/json": {
                      "schema": {
                        "type": "object",
                        "properties": {
                          "command": {
                            "type": "string",
                            "description": "The exact shell command to run on the Mac (e.g. ls -la, git status, cargo build, npm test)"
                          },
                          "workdir": {
                            "type": "string",
                            "description": "Optional working directory"
                          }
                        },
                        "required": ["command"]
                      }
                    }
                  }
                },
                "responses": {
                  "200": {
                    "description": "Command execution output",
                    "content": {
                      "application/json": {
                        "schema": {
                          "type": "object",
                          "properties": {
                            "success": { "type": "boolean" },
                            "stdout": { "type": "string" },
                            "stderr": { "type": "string" },
                            "exitCode": { "type": "integer" },
                            "durationMs": { "type": "integer" },
                            "error": { "type": "string" }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "components": {
            "securitySchemes": {
              "BearerAuth": {
                "type": "http",
                "scheme": "bearer"
              }
            }
          },
          "security": [
            {
              "BearerAuth": []
            }
          ]
        }
        """
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("ChatGPT & Tunnel Setup")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Connect your web ChatGPT browser session securely to your Mac with zero configuration.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Live Connection Status Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "network")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                        Text("Cloudflare Quick Tunnel")
                            .font(.headline)
                        
                        Spacer()
                        
                        // Status Badge
                        HStack(spacing: 6) {
                            Circle()
                                .fill(tunnelManager.status == .stopped ? Color.gray : (tunnelManager.publicUrl != nil ? Color.green : Color.yellow))
                                .frame(width: 8, height: 8)
                            Text(tunnelManager.status == .stopped ? "Disconnected" : (tunnelManager.publicUrl != nil ? "Tunnel Active" : "Starting..."))
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                    
                    // Tunnel URL
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Public HTTPS Endpoint:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text(tunnelManager.publicUrl ?? "Tunnel stopped. Click 'Start Tunnel' to generate a secure HTTPS URL.")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(tunnelManager.publicUrl != nil ? .primary : .secondary)
                                .textSelection(.enabled)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            if let url = tunnelManager.publicUrl {
                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(url, forType: .string)
                                    uiState.copiedUrl = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { uiState.copiedUrl = false }
                                }) {
                                    Label(uiState.copiedUrl ? "Copied!" : "Copy URL", systemImage: uiState.copiedUrl ? "checkmark" : "doc.on.doc")
                                }
                                .buttonStyle(.bordered)
                                
                                Button(action: {
                                    if let u = URL(string: url + "/health") {
                                        NSWorkspace.shared.open(u)
                                    }
                                }) {
                                    Label("Test", systemImage: "arrow.up.right.square")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(10)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                    }
                    
                    // API Bearer Token
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Security Bearer Token:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text(uiState.showToken ? settings.apiToken : String(repeating: "•", count: 24))
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                            
                            Spacer()
                            
                            Button(action: { uiState.showToken.toggle() }) {
                                Image(systemName: uiState.showToken ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.bordered)
                            .help(uiState.showToken ? "Hide token" : "Show token")
                            
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(settings.apiToken, forType: .string)
                                uiState.copiedToken = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { uiState.copiedToken = false }
                            }) {
                                Label(uiState.copiedToken ? "Copied!" : "Copy Token", systemImage: uiState.copiedToken ? "checkmark" : "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(10)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                    }
                    
                    // Action Buttons
                    HStack {
                        if tunnelManager.isRunning {
                            Button(role: .destructive, action: {
                                tunnelManager.stopTunnel()
                            }) {
                                Label("Stop Tunnel", systemImage: "stop.fill")
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button(action: {
                                tunnelManager.startTunnel(port: settings.port)
                            }) {
                                Label("Start Cloudflare Tunnel", systemImage: "bolt.fill")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        Spacer()
                        
                        Text("Local Port: \(settings.port)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                
                // Instructions Tabs
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Integration Guide", selection: Binding(
                        get: { uiState.selectedGuideTab },
                        set: { uiState.selectedGuideTab = $0 }
                    )) {
                        Text("Custom GPT Action (Recommended)").tag(0)
                        Text("Remote MCP Connector").tag(1)
                    }
                    .pickerStyle(.segmented)
                    
                    if uiState.selectedGuideTab == 0 {
                        // Custom GPT Guide
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How to add to ChatGPT in Browser:")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                StepRow(number: 1, title: "Start the Tunnel above", detail: "Click 'Start Cloudflare Tunnel' so your Mac has a live public HTTPS address.")
                                StepRow(number: 2, title: "Open ChatGPT in your browser", detail: "Go to chatgpt.com -> Explore GPTs -> Click '+ Create' (top right).")
                                StepRow(number: 3, title: "Click 'Create new action'", detail: "Switch to the 'Configure' tab, scroll to the bottom, and click 'Create new action'.")
                                StepRow(number: 4, title: "Set Authentication to Bearer", detail: "Under Authentication, select 'API Key', Auth Type 'Bearer', and paste your Security Bearer Token.")
                                StepRow(number: 5, title: "Paste the OpenAPI Schema", detail: "Click the 'Copy OpenAPI 3.1 Schema' button below and paste it into the Schema box.")
                                StepRow(number: 6, title: "Ready to control your Mac!", detail: "In the preview or saved GPT, say: 'Run git status on my Mac' or 'List files in my workspace'. RemoteCommander will pop up an approval prompt for each command!")
                            }
                            
                            Divider()
                            
                            // OpenAPI Schema Box
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("OpenAPI 3.1 Schema:")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Button(action: {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(openApiSchema, forType: .string)
                                        uiState.copiedSchema = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { uiState.copiedSchema = false }
                                    }) {
                                        Label(uiState.copiedSchema ? "Copied!" : "Copy OpenAPI 3.1 Schema", systemImage: uiState.copiedSchema ? "checkmark" : "doc.on.doc")
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                                
                                Text(openApiSchema)
                                    .font(.system(size: 11, design: .monospaced))
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.black.opacity(0.85))
                                    .foregroundColor(.green.opacity(0.9))
                                    .cornerRadius(8)
                                    .lineLimit(12)
                            }
                        }
                        .padding(16)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                    } else {
                        // MCP Guide
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Model Context Protocol (MCP) Setup:")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                StepRow(number: 1, title: "Server Endpoint", detail: "\(effectiveUrl)/mcp")
                                StepRow(number: 2, title: "SSE Endpoint", detail: "\(effectiveUrl)/sse")
                                StepRow(number: 3, title: "Authorization Header", detail: "Authorization: Bearer \(settings.apiToken)")
                                StepRow(number: 4, title: "Exposed Tool", detail: "'execute_command' (runs shell command on Mac with native approval prompt).")
                            }
                        }
                        .padding(16)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
    }
}

struct StepRow: View {
    let number: Int
    let title: String
    let detail: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 22, height: 22)
                .background(Color.accentColor.opacity(0.2))
                .foregroundColor(.accentColor)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
