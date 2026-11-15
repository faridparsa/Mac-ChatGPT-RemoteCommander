import SwiftUI

struct ApprovalsView: View {
    @ObservedObject var commandManager: CommandManager
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Command Approvals")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Review and approve shell commands requested by ChatGPT in your browser.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if !commandManager.pendingRequests.isEmpty {
                    Text("\(commandManager.pendingRequests.count) Pending")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                }
            }
            .padding()
            
            Divider()
            
            if commandManager.pendingRequests.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green.opacity(0.8))
                    Text("No Pending Approvals")
                        .font(.headline)
                    Text("When ChatGPT requests to run a command on your Mac, it will appear here for your review and confirmation.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(commandManager.pendingRequests) { request in
                            ApprovalCard(
                                request: request,
                                onApprove: {
                                    commandManager.approveRequest(id: request.id)
                                },
                                onReject: {
                                    commandManager.rejectRequest(id: request.id)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

struct ApprovalCard: View {
    let request: CommandRequest
    let onApprove: () -> Void
    let onReject: () -> Void
    
    var riskColor: Color {
        switch request.risk.level {
        case .safe: return .green
        case .moderate: return .orange
        case .high: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top Bar: Source & Risk
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .foregroundColor(.accentColor)
                    Text(request.source)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                Spacer()
                
                // Risk Badge
                HStack(spacing: 4) {
                    Image(systemName: request.risk.level.icon)
                    Text(request.risk.level.rawValue)
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(riskColor.opacity(0.15))
                .foregroundColor(riskColor)
                .clipShape(Capsule())
            }
            
            // Command Code Block
            VStack(alignment: .leading, spacing: 6) {
                Text("Requested Command:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(request.command)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .textSelection(.enabled)
                    Spacer()
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(request.command, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Copy command")
                }
                .padding(12)
                .background(Color.black.opacity(0.85))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(riskColor.opacity(0.4), lineWidth: 1)
                )
            }
            
            // Working Directory & Details
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.secondary)
                    Text(request.workingDirectory)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Spacer()
                
                Text(request.requestedAt, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Risk Reasons if any
            if !request.risk.reasons.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(request.risk.reasons, id: \.self) { reason in
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.caption2)
                            Text(reason)
                                .font(.caption2)
                        }
                        .foregroundColor(riskColor)
                    }
                }
            }
            
            Divider()
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(role: .destructive, action: onReject) {
                    Label("Reject", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                
                Button(action: onApprove) {
                    Label("Approve & Run", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(riskColor == .red ? .orange : .accentColor)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}
