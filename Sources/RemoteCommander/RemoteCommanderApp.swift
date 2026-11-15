import SwiftUI
import AppKit

@MainActor
public class AppCoordinator: ObservableObject {
    public let settings = AppSettings()
    public let commandManager = CommandManager()
    public let tunnelManager = TunnelManager()
    public let uiState = UIState()
    private var server: HTTPServer?
    
    public init() {
        start()
    }
    
    public func start() {
        guard server == nil else { return }
        let newServer = HTTPServer(
            port: settings.port,
            commandManager: commandManager,
            settings: settings
        )
        do {
            try newServer.start()
            self.server = newServer
            print("🚀 RemoteCommander local server started on port \(settings.port)")
            
            // Auto-start tunnel if cloudflared is present
            if tunnelManager.findCloudflaredBinary() != nil {
                tunnelManager.startTunnel(port: settings.port)
            }
        } catch {
            print("❌ Failed to start local server: \(error)")
        }
    }
}

@main
struct RemoteCommanderApp: App {
    @StateObject private var coordinator = AppCoordinator()
    
    var body: some Scene {
        WindowGroup {
            ContentView(
                commandManager: coordinator.commandManager,
                tunnelManager: coordinator.tunnelManager,
                settings: coordinator.settings,
                uiState: coordinator.uiState
            )
            .frame(minWidth: 880, minHeight: 560)
            .onAppear {
                coordinator.start()
            }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandMenu("Tunnel") {
                Button("Start Cloudflare Tunnel") {
                    coordinator.tunnelManager.startTunnel(port: coordinator.settings.port)
                }
                .disabled(coordinator.tunnelManager.isRunning)
                .keyboardShortcut("t", modifiers: [.command])
                
                Button("Stop Cloudflare Tunnel") {
                    coordinator.tunnelManager.stopTunnel()
                }
                .disabled(!coordinator.tunnelManager.isRunning)
                .keyboardShortcut(".", modifiers: [.command])
            }
            
            CommandMenu("Terminal") {
                Button("Clear Terminal") {
                    coordinator.commandManager.clearTerminal()
                }
                .keyboardShortcut("k", modifiers: [.command])
                
                Button("Clear History") {
                    coordinator.commandManager.clearHistory()
                }
            }
        }
    }
}
