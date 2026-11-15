import SwiftUI

struct TerminalView: View {
    @ObservedObject var commandManager: CommandManager
    @ObservedObject var settings: AppSettings
    @ObservedObject var uiState: UIState
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal Header / Toolbar
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 10, height: 10)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                    
                    Text("Terminal Console")
                        .font(.headline)
                        .padding(.leading, 8)
                    
                    if commandManager.isExecuting {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Executing...")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                        .padding(.leading, 6)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                        Text(settings.workingDirectory)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 220, alignment: .trailing)
                    
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(commandManager.terminalOutput, forType: .string)
                    }) {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .help("Copy full terminal output")
                    
                    Button(action: {
                        commandManager.clearTerminal()
                    }) {
                        Label("Clear", systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .help("Clear terminal screen")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Console Output Area
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(commandManager.terminalOutput)
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundColor(Color(red: 0.88, green: 0.92, blue: 0.95))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                        
                        Color.clear
                            .frame(height: 1)
                            .id("terminalBottom")
                    }
                }
                .background(Color(red: 0.08, green: 0.09, blue: 0.11))
                .onChange(of: commandManager.terminalOutput) { _, _ in
                    if uiState.autoScroll {
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo("terminalBottom", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
}
