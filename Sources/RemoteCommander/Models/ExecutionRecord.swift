import Foundation

public struct ExecutionRecord: Identifiable, Equatable, Hashable {
    public let id: UUID
    public let request: CommandRequest
    public let startedAt: Date
    public var finishedAt: Date?
    public var stdout: String
    public var stderr: String
    public var exitCode: Int32?
    public var errorMessage: String?
    
    public var duration: TimeInterval? {
        guard let finishedAt = finishedAt else { return nil }
        return finishedAt.timeIntervalSince(startedAt)
    }
    
    public var formattedDuration: String {
        guard let d = duration else { return "..." }
        if d < 1.0 {
            return String(format: "%.0f ms", d * 1000)
        } else {
            return String(format: "%.2f s", d)
        }
    }
    
    public var isSuccess: Bool {
        return exitCode == 0
    }
    
    public init(
        id: UUID = UUID(),
        request: CommandRequest,
        startedAt: Date = Date(),
        finishedAt: Date? = nil,
        stdout: String = "",
        stderr: String = "",
        exitCode: Int32? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.request = request
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
        self.errorMessage = errorMessage
    }
}
