import Foundation
import SwiftUI
import AppKit

public struct CommandResponse: Codable, Sendable {
    public let success: Bool
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
    public let durationMs: Int
    public let error: String?
}

@MainActor
public class CommandManager: ObservableObject {
    @Published public var pendingRequests: [CommandRequest] = []
    @Published public var activeRecord: ExecutionRecord?
    @Published public var history: [ExecutionRecord] = []
    @Published public var terminalOutput: String = ""
    @Published public var isExecuting: Bool = false
    @Published public var currentShowingApproval: CommandRequest? = nil
    
    private var continuations: [UUID: CheckedContinuation<Bool, Never>] = [:]
    private let runner = ProcessRunner()
    
    public init() {
        self.terminalOutput = "RemoteCommander Terminal Ready.\nWaiting for commands from ChatGPT...\n"
    }
    
    /// Called when an incoming command arrives from ChatGPT / MCP / REST
    public func handleIncomingCommand(
        command: String,
        workingDir: String?,
        source: String = "ChatGPT Web",
        settings: AppSettings
    ) async -> CommandResponse {
        let targetDir = (workingDir != nil && !workingDir!.isEmpty) ? workingDir! : settings.workingDirectory
        var request = CommandRequest(
            command: command,
            workingDirectory: targetDir,
            source: source
        )
        
        // Auto-approve if safe and enabled
        let shouldAutoApprove = settings.autoApproveSafe && (request.risk.level == .safe)
        
        let approved: Bool
        if shouldAutoApprove {
            approved = true
            request.status = .approved
        } else {
            // Queue for user approval
            pendingRequests.append(request)
            currentShowingApproval = request
            NSSound.beep()
            
            approved = await withCheckedContinuation { continuation in
                continuations[request.id] = continuation
            }
        }
        
        if !approved {
            request.status = .rejected
            let rejectedRecord = ExecutionRecord(
                request: request,
                startedAt: Date(),
                finishedAt: Date(),
                stdout: "",
                stderr: "",
                exitCode: -1,
                errorMessage: "Execution rejected by user on Mac."
            )
            history.insert(rejectedRecord, at: 0)
            appendTerminal(line: "❌ [REJECTED] \(command)\n")
            
            return CommandResponse(
                success: false,
                stdout: "",
                stderr: "Command execution was rejected by the user.",
                exitCode: 1,
                durationMs: 0,
                error: "Execution rejected by user"
            )
        }
        
        // Approved: Execute the command
        request.status = .executing
        var record = ExecutionRecord(request: request, startedAt: Date())
        activeRecord = record
        isExecuting = true
        
        appendTerminal(line: "\n🚀 [RUNNING] \(command)\n📂 Working Dir: \(targetDir)\n----------------------------------------\n")
        
        let result = await runner.execute(
            command: command,
            workingDirectory: targetDir,
            shell: settings.defaultShell,
            timeout: settings.executionTimeoutSeconds
        ) { [weak self] chunk, isErr in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.appendTerminal(line: chunk)
                if isErr {
                    self.activeRecord?.stderr.append(chunk)
                } else {
                    self.activeRecord?.stdout.append(chunk)
                }
            }
        }
        
        let durationMs = Int(result.duration * 1000)
        record.finishedAt = Date()
        record.stdout = result.stdout
        record.stderr = result.stderr
        record.exitCode = result.exitCode
        record.errorMessage = result.errorMessage
        
        if result.exitCode == 0 {
            request.status = .completed
            appendTerminal(line: "\n✅ [EXIT 0] Completed in \(durationMs) ms\n")
        } else {
            request.status = .failed
            appendTerminal(line: "\n⚠️ [EXIT \(result.exitCode)] \(result.errorMessage ?? "Failed")\n")
        }
        
        history.insert(record, at: 0)
        activeRecord = nil
        isExecuting = false
        
        return CommandResponse(
            success: result.exitCode == 0,
            stdout: result.stdout,
            stderr: result.stderr,
            exitCode: result.exitCode,
            durationMs: durationMs,
            error: result.errorMessage
        )
    }
    
    public func approveRequest(id: UUID) {
        if let index = pendingRequests.firstIndex(where: { $0.id == id }) {
            pendingRequests.remove(at: index)
        }
        if currentShowingApproval?.id == id {
            currentShowingApproval = pendingRequests.first
        }
        if let continuation = continuations.removeValue(forKey: id) {
            continuation.resume(returning: true)
        }
    }
    
    public func rejectRequest(id: UUID) {
        if let index = pendingRequests.firstIndex(where: { $0.id == id }) {
            pendingRequests.remove(at: index)
        }
        if currentShowingApproval?.id == id {
            currentShowingApproval = pendingRequests.first
        }
        if let continuation = continuations.removeValue(forKey: id) {
            continuation.resume(returning: false)
        }
    }
    
    public func clearTerminal() {
        terminalOutput = "Terminal cleared.\n"
    }
    
    public func clearHistory() {
        history.removeAll()
    }
    
    private func appendTerminal(line: String) {
        terminalOutput.append(line)
        // Keep terminal buffer manageable (last ~100k chars)
        if terminalOutput.count > 120_000 {
            terminalOutput = String(terminalOutput.suffix(80_000))
        }
    }
}
