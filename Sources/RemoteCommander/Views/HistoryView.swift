import SwiftUI

struct HistoryView: View {
    @ObservedObject var commandManager: CommandManager
    @ObservedObject var uiState: UIState
    
    var filteredHistory: [ExecutionRecord] {
        commandManager.history.filter { record in
            let matchesSearch = uiState.searchText.isEmpty || record.request.command.localizedCaseInsensitiveContains(uiState.searchText)
            
            let matchesFilter: Bool
            switch uiState.selectedFilter {
            case .all:
                matchesFilter = true
            case .succeeded:
                matchesFilter = record.request.status == .completed && record.exitCode == 0
            case .failed:
                matchesFilter = record.request.status == .failed || (record.exitCode != nil && record.exitCode != 0)
            case .rejected:
                matchesFilter = record.request.status == .rejected
            }
            
            return matchesSearch && matchesFilter
        }
    }
    
    var body: some View {
        HSplitView {
            // Left list of records
            VStack(spacing: 0) {
                // Top control bar
                HStack(spacing: 12) {
                    TextField("Search history...", text: Binding(
                        get: { uiState.searchText },
                        set: { uiState.searchText = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    
                    Picker("Filter", selection: Binding(
                        get: { uiState.selectedFilter },
                        set: { uiState.selectedFilter = $0 }
                    )) {
                        ForEach(HistoryFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 240)
                    
                    Button(role: .destructive, action: {
                        commandManager.clearHistory()
                        uiState.selectedRecord = nil
                    }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .help("Clear execution history")
                }
                .padding()
                
                Divider()
                
                if filteredHistory.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("No Execution History")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredHistory, selection: Binding(
                        get: { uiState.selectedRecord },
                        set: { uiState.selectedRecord = $0 }
                    )) { record in
                        HistoryRow(record: record)
                            .tag(record)
                    }
                    .listStyle(.inset)
                }
            }
            .frame(minWidth: 320)
            
            // Right detail inspector
            if let record = uiState.selectedRecord {
                HistoryDetailView(record: record)
                    .frame(minWidth: 360)
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("Select a command to view details and outputs")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct HistoryRow: View {
    let record: ExecutionRecord
    
    var statusColor: Color {
        switch record.request.status {
        case .completed: return record.exitCode == 0 ? .green : .red
        case .failed: return .red
        case .rejected: return .gray
        case .executing: return .blue
        case .pendingApproval: return .orange
        case .approved: return .green
        case .timedOut: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: record.request.status.icon)
                    Text(record.request.status.rawValue)
                }
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(statusColor)
                
                Spacer()
                
                Text(record.formattedDuration)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(record.startedAt, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(record.request.command)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .lineLimit(2)
            
            HStack {
                Text(record.request.workingDirectory)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                if let code = record.exitCode {
                    Text("Exit: \(code)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(code == 0 ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                        .foregroundColor(code == 0 ? .green : .red)
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct HistoryDetailView: View {
    let record: ExecutionRecord
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Command Box
                VStack(alignment: .leading, spacing: 6) {
                    Text("Command")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(record.request.command)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                        Spacer()
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(record.request.command, forType: .string)
                        }) {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                // Metadata Grid
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        Text("Status:").foregroundColor(.secondary)
                        Text(record.request.status.rawValue).fontWeight(.semibold)
                    }
                    GridRow {
                        Text("Exit Code:").foregroundColor(.secondary)
                        Text(record.exitCode != nil ? "\(record.exitCode!)" : "None")
                    }
                    GridRow {
                        Text("Duration:").foregroundColor(.secondary)
                        Text(record.formattedDuration)
                    }
                    GridRow {
                        Text("Directory:").foregroundColor(.secondary)
                        Text(record.request.workingDirectory).textSelection(.enabled)
                    }
                    GridRow {
                        Text("Executed At:").foregroundColor(.secondary)
                        Text(record.startedAt, format: .dateTime)
                    }
                }
                .font(.caption)
                
                Divider()
                
                // Stdout
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Standard Output (stdout)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        Spacer()
                        if !record.stdout.isEmpty {
                            Button("Copy stdout") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(record.stdout, forType: .string)
                            }
                            .font(.caption2)
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    Text(record.stdout.isEmpty ? "(No stdout output)" : record.stdout)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.textBackgroundColor))
                        .foregroundColor(Color(NSColor.textColor))
                        .cornerRadius(6)
                        .textSelection(.enabled)
                }
                
                // Stderr
                if !record.stderr.isEmpty || record.errorMessage != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Standard Error (stderr)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                            Spacer()
                            Button("Copy stderr") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(record.stderr, forType: .string)
                            }
                            .font(.caption2)
                            .buttonStyle(.bordered)
                        }
                        
                        Text(record.stderr.isEmpty ? (record.errorMessage ?? "") : record.stderr)
                            .font(.system(size: 11, design: .monospaced))
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(6)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding()
        }
    }
}
