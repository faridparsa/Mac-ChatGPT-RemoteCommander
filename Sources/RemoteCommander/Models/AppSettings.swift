import Foundation

@MainActor
public class AppSettings: ObservableObject {
    @Published public var workingDirectory: String {
        didSet { UserDefaults.standard.set(workingDirectory, forKey: "rc_working_directory") }
    }
    
    @Published public var defaultShell: String {
        didSet { UserDefaults.standard.set(defaultShell, forKey: "rc_default_shell") }
    }
    
    @Published public var port: UInt16 {
        didSet { UserDefaults.standard.set(Int(port), forKey: "rc_port") }
    }
    
    @Published public var apiToken: String {
        didSet { UserDefaults.standard.set(apiToken, forKey: "rc_api_token") }
    }
    
    @Published public var autoApproveSafe: Bool {
        didSet { UserDefaults.standard.set(autoApproveSafe, forKey: "rc_auto_approve_safe") }
    }
    
    @Published public var executionTimeoutSeconds: Double {
        didSet { UserDefaults.standard.set(executionTimeoutSeconds, forKey: "rc_exec_timeout") }
    }
    
    public init() {
        let defaults = UserDefaults.standard
        
        let initialDir: String
        if let savedDir = defaults.string(forKey: "rc_working_directory"), !savedDir.isEmpty {
            initialDir = savedDir
        } else {
            initialDir = FileManager.default.homeDirectoryForCurrentUser.path
        }
        self.workingDirectory = initialDir
        
        self.defaultShell = defaults.string(forKey: "rc_default_shell") ?? "/bin/zsh"
        
        let savedPort = defaults.integer(forKey: "rc_port")
        self.port = savedPort > 0 ? UInt16(savedPort) : 4040
        
        if let savedToken = defaults.string(forKey: "rc_api_token"), !savedToken.isEmpty {
            self.apiToken = savedToken
        } else {
            let newToken = "rc_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(24).lowercased()
            self.apiToken = newToken
            defaults.set(newToken, forKey: "rc_api_token")
        }
        
        self.autoApproveSafe = defaults.bool(forKey: "rc_auto_approve_safe")
        
        let savedTimeout = defaults.double(forKey: "rc_exec_timeout")
        self.executionTimeoutSeconds = savedTimeout > 0 ? savedTimeout : 60.0
    }
    
    public func regenerateToken() {
        let newToken = "rc_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(24).lowercased()
        self.apiToken = newToken
    }
}
