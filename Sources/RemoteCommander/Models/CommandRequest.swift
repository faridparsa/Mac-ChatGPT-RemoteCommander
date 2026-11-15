import Foundation

public enum RequestStatus: String, CaseIterable, Codable {
    case pendingApproval = "Pending Approval"
    case approved = "Approved"
    case rejected = "Rejected"
    case executing = "Executing"
    case completed = "Completed"
    case failed = "Failed"
    case timedOut = "Timed Out"
    
    public var icon: String {
        switch self {
        case .pendingApproval: return "hand.raised.fill"
        case .approved: return "checkmark.circle"
        case .rejected: return "xmark.circle.fill"
        case .executing: return "play.circle.fill"
        case .completed: return "checkmark.seal.fill"
        case .failed: return "exclamationmark.octagon.fill"
        case .timedOut: return "clock.badge.exclamationmark"
        }
    }
}

public struct CommandRequest: Identifiable, Equatable, Hashable {
    public let id: UUID
    public let command: String
    public let workingDirectory: String
    public let source: String
    public let requestedAt: Date
    public var status: RequestStatus
    public let risk: RiskAssessment
    
    public init(
        id: UUID = UUID(),
        command: String,
        workingDirectory: String,
        source: String = "ChatGPT Web",
        requestedAt: Date = Date(),
        status: RequestStatus = .pendingApproval
    ) {
        self.id = id
        self.command = command
        self.workingDirectory = workingDirectory
        self.source = source
        self.requestedAt = requestedAt
        self.status = status
        self.risk = RiskAnalyzer.assess(command: command)
    }
}
