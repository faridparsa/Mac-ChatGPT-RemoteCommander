import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var tunnelManager: TunnelManager
    @ObservedObject var uiState: UIState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings & Security")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Configure execution directories, shell environment, and approval safety.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Working Directory Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Execution Directory")
                        .font(.headline)
                    
                    HStack {
                        TextField("Working Directory", text: Binding(
                            get: { settings.workingDirectory },
                            set: { settings.workingDirectory = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        
                        Button("Browse...") {
                            chooseDirectory()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Text("Commands requested by ChatGPT will run inside this folder by default unless another directory is explicitly specified in the request.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                
                // Shell & Environment Section
                VStack(alignment: .leading, spacing: 14) {
                    Text("Shell & Environment")
                        .font(.headline)
                    
                    HStack {
                        Text("Default Shell:")
                            .frame(width: 140, alignment: .leading)
                        
                        Picker("", selection: Binding(
                            get: { settings.defaultShell },
                            set: { settings.defaultShell = $0 }
                        )) {
                            Text("Zsh (/bin/zsh)").tag("/bin/zsh")
                            Text("Bash (/bin/bash)").tag("/bin/bash")
                            Text("Standard Shell (/bin/sh)").tag("/bin/sh")
                        }
                        .pickerStyle(.menu)
                    }
                    
                    HStack {
                        Text("Execution Timeout:")
                            .frame(width: 140, alignment: .leading)
                        
                        TextField("Timeout in seconds", value: Binding(
                            get: { settings.executionTimeoutSeconds },
                            set: { settings.executionTimeoutSeconds = $0 }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        
                        Text("seconds")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Local Server Port:")
                            .frame(width: 140, alignment: .leading)
                        
                        TextField("Port", value: Binding(
                            get: { settings.port },
                            set: { settings.port = $0 }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                
                // Safety & Approval Preferences
                VStack(alignment: .leading, spacing: 14) {
                    Text("Approval Policy")
                        .font(.headline)
                    
                    Toggle(isOn: Binding(
                        get: { settings.autoApproveSafe },
                        set: { settings.autoApproveSafe = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-approve Safe Read-Only Commands")
                                .fontWeight(.medium)
                            Text("Automatically approve read-only commands (e.g. ls, pwd, git status, cat, echo, date) without a confirmation popup.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                
                // Security & Token Management
                VStack(alignment: .leading, spacing: 14) {
                    Text("API Security Token")
                        .font(.headline)
                    
                    Text("The Bearer token prevents unauthorized web requests from accessing your Mac.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(settings.apiToken)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                        
                        Spacer()
                        
                        Button("Regenerate Token") {
                            uiState.showTokenAlert = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                
                // Cloudflared binary status
                VStack(alignment: .leading, spacing: 10) {
                    Text("Cloudflare Tunnel Binary")
                        .font(.headline)
                    
                    let path = tunnelManager.findCloudflaredBinary()
                    HStack {
                        Image(systemName: path != nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(path != nil ? .green : .red)
                        Text(path != nil ? "Installed: \(path!)" : "Not Found (Install via 'brew install cloudflared' or place in bin/)")
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
            }
            .padding()
        }
        .alert("Regenerate Security Token?", isPresented: Binding(
            get: { uiState.showTokenAlert },
            set: { uiState.showTokenAlert = $0 }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Regenerate", role: .destructive) {
                settings.regenerateToken()
            }
        } message: {
            Text("Regenerating the token will invalidate the old token. You will need to update the Authentication setting in your ChatGPT Custom GPT.")
        }
    }
    
    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: settings.workingDirectory)
        
        if panel.runModal() == .OK, let url = panel.url {
            settings.workingDirectory = url.path
        }
    }
}
