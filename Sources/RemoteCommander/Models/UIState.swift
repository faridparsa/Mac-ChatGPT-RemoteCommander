import Foundation
import SwiftUI

public enum HistoryFilter: String, CaseIterable {
    case all = "All"
    case succeeded = "Succeeded"
    case failed = "Failed"
    case rejected = "Rejected"
}

public enum NavigationPanel: String, CaseIterable, Identifiable {
    case approvals = "Approvals"
    case terminal = "Terminal"
    case history = "History"
    case tunnel = "ChatGPT Setup"
    case settings = "Settings"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .approvals: return "hand.raised.fill"
        case .terminal: return "apple.terminal.fill"
        case .history: return "clock.fill"
        case .tunnel: return "network"
        case .settings: return "gearshape.fill"
        }
    }
}

@MainActor
public class UIState: ObservableObject {
    @Published public var selectedPanel: NavigationPanel = .approvals
    @Published public var searchText: String = ""
    @Published public var selectedFilter: HistoryFilter = .all
    @Published public var selectedRecord: ExecutionRecord? = nil
    @Published public var autoScroll: Bool = true
    @Published public var showToken: Bool = false
    @Published public var copiedUrl: Bool = false
    @Published public var copiedToken: Bool = false
    @Published public var copiedSchema: Bool = false
    @Published public var selectedGuideTab: Int = 0
    @Published public var showTokenAlert: Bool = false
    
    public init() {}
}
