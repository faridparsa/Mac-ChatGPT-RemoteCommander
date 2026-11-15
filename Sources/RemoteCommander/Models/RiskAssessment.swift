import Foundation

public enum RiskLevel: String, CaseIterable, Codable {
    case safe = "Safe"
    case moderate = "Moderate"
    case high = "High Risk"
    
    public var colorName: String {
        switch self {
        case .safe: return "green"
        case .moderate: return "orange"
        case .high: return "red"
        }
    }
    
    public var icon: String {
        switch self {
        case .safe: return "checkmark.shield"
        case .moderate: return "exclamationmark.triangle"
        case .high: return "xmark.octagon.fill"
        }
    }
}

public struct RiskAssessment: Equatable, Hashable {
    public let level: RiskLevel
    public let reasons: [String]
    
    public init(level: RiskLevel, reasons: [String]) {
        self.level = level
        self.reasons = reasons
    }
}

public struct RiskAnalyzer {
    // Dangerous commands / patterns
    private static let highRiskPatterns = [
        "rm\\s+-r[fF]", "rm\\s+-f[rR]", "rmdir",
        "sudo\\s+", "dd\\s+if=", "mkfs",
        "chmod\\s+-[R\\s]*777", "chown\\s+-R",
        ">\\s*/dev/sd", ">\\s*/dev/disk",
        ":\\(\\)\\s*\\{\\s*:\\|:&\\s*\\};:", // fork bomb
        "curl\\s+.*\\|\\s*(ba)?sh", "wget\\s+.*\\|\\s*(ba)?sh",
        "kill\\s+-9", "killall\\s+-9"
    ]
    
    // Read-only or safe patterns
    private static let safePrefixes = [
        "ls", "pwd", "echo", "date", "whoami", "uname", "cat", "head", "tail",
        "grep", "rg", "find", "stat", "file", "wc", "which", "whereis",
        "git status", "git log", "git diff", "git show", "git branch",
        "sw_vers", "df", "du", "ps", "top", "uptime", "env"
    ]
    
    public static func assess(command: String) -> RiskAssessment {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return RiskAssessment(level: .safe, reasons: ["Empty command"])
        }
        
        var reasons: [String] = []
        
        // Check for high risk patterns
        for pattern in highRiskPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: trimmed.utf16.count)
                if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                    reasons.append("Contains high-risk pattern: \(pattern)")
                }
            }
        }
        
        if !reasons.isEmpty {
            return RiskAssessment(level: .high, reasons: reasons)
        }
        
        // Check if root command matches safe prefixes
        for safe in safePrefixes {
            if trimmed == safe || trimmed.starts(with: safe + " ") {
                // Ensure no pipe or redirection overrides safety
                if !trimmed.contains(">") && !trimmed.contains("|") && !trimmed.contains(";") && !trimmed.contains("&&") {
                    return RiskAssessment(level: .safe, reasons: ["Standard read-only command: \(safe)"])
                }
            }
        }
        
        // Moderate risk for normal file creation, compilation, package management, etc.
        return RiskAssessment(
            level: .moderate,
            reasons: ["Executes standard shell operations or script commands"]
        )
    }
}
