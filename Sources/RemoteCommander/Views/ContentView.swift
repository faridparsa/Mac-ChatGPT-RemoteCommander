import SwiftUI

struct ContentView: View {
    @ObservedObject var commandManager: CommandManager
    @ObservedObject var tunnelManager: TunnelManager
    @ObservedObject var settings: AppSettings
    @ObservedObject var uiState: UIState
    
    var body: some View {
        NavigationSplitView {
            List(selection: Binding(
                get: { uiState.selectedPanel },
                set: { if let p = $0 { uiState.selectedPanel = p } }
            )) {
                Section("Remote Commander") {
                    NavigationLink(value: NavigationPanel.approvals) {
                        HStack {
                            Label(NavigationPanel.approvals.rawValue, systemImage: NavigationPanel.approvals.icon)
                            Spacer()
                            if !commandManager.pendingRequests.isEmpty {
                                Text("\(commandManager.pendingRequests.count)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    
                    NavigationLink(value: NavigationPanel.terminal) {
                        HStack {
                            Label(NavigationPanel.terminal.rawValue, systemImage: NavigationPanel.terminal.icon)
                            Spacer()
                            if commandManager.isExecuting {
                                ProgressView()
                                    .controlSize(.mini)
                            }
                        }
                    }
                    
                    NavigationLink(value: NavigationPanel.history) {
                        HStack {
                            Label(NavigationPanel.history.rawValue, systemImage: NavigationPanel.history.icon)
                            Spacer()
                            if !commandManager.history.isEmpty {
                                Text("\(commandManager.history.count)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section("Connection & Config") {
                    NavigationLink(value: NavigationPanel.tunnel) {
                        HStack {
                            Label(NavigationPanel.tunnel.rawValue, systemImage: NavigationPanel.tunnel.icon)
                            Spacer()
                            Circle()
                                .fill(tunnelManager.publicUrl != nil ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    NavigationLink(value: NavigationPanel.settings) {
                        Label(NavigationPanel.settings.rawValue, systemImage: NavigationPanel.settings.icon)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
            
            // Sidebar Footer status
            VStack(alignment: .leading, spacing: 4) {
                Divider()
                HStack(spacing: 6) {
                    Circle()
                        .fill(tunnelManager.publicUrl != nil ? Color.green : (tunnelManager.isRunning ? Color.yellow : Color.gray))
                        .frame(width: 7, height: 7)
                    Text(tunnelManager.publicUrl != nil ? "Tunnel Online" : (tunnelManager.isRunning ? "Connecting..." : "Tunnel Offline"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        } detail: {
            VStack(spacing: 0) {
                // Top alert banner if an approval is waiting and user is on another view
                if let pending = commandManager.pendingRequests.first, uiState.selectedPanel != .approvals {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised.fill")
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pending Approval Request")
                                .font(.caption)
                                .fontWeight(.bold)
                            Text(pending.command)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Button("Reject") {
                            commandManager.rejectRequest(id: pending.id)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("Approve") {
                            commandManager.approveRequest(id: pending.id)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.small)
                        
                        Button("Review") {
                            uiState.selectedPanel = .approvals
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.15))
                    
                    Divider()
                }
                
                // Active panel
                switch uiState.selectedPanel {
                case .approvals:
                    ApprovalsView(commandManager: commandManager, settings: settings)
                case .terminal:
                    TerminalView(commandManager: commandManager, settings: settings, uiState: uiState)
                case .history:
                    HistoryView(commandManager: commandManager, uiState: uiState)
                case .tunnel:
                    TunnelSetupView(tunnelManager: tunnelManager, settings: settings, uiState: uiState)
                case .settings:
                    SettingsView(settings: settings, tunnelManager: tunnelManager, uiState: uiState)
                }
            }
        }
    }
}
