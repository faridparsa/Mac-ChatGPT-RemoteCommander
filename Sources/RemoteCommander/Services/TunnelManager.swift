import Foundation
import Combine

public enum TunnelStatus: Equatable {
    case stopped
    case starting
    case connected(url: String)
    case failed(error: String)
    
    public var label: String {
        switch self {
        case .stopped: return "Disconnected"
        case .starting: return "Connecting Tunnel..."
        case .connected(let url): return "Active: \(url)"
        case .failed(let err): return "Error: \(err)"
        }
    }
}

@MainActor
public class TunnelManager: ObservableObject {
    @Published public var status: TunnelStatus = .stopped
    @Published public var publicUrl: String? = nil
    @Published public var tunnelLogs: String = ""
    @Published public var isRunning: Bool = false
    
    private var process: Process?
    private var stdoutPipe: Pipe?
    
    public init() {}
    
    public func findCloudflaredBinary() -> String? {
        let fm = FileManager.default
        
        // 1. Bundle Resources
        if let resourcePath = Bundle.main.resourcePath {
            let inBundle = (resourcePath as NSString).appendingPathComponent("cloudflared")
            if fm.isExecutableFile(atPath: inBundle) {
                return inBundle
            }
        }
        
        // 2. Local bin directory in workspace or user directory
        let candidatePaths = [
            FileManager.default.currentDirectoryPath + "/bin/cloudflared",
            Bundle.main.bundlePath + "/Contents/Resources/cloudflared",
            NSString(string: "~/.remotecommander/bin/cloudflared").expandingTildeInPath,
            "/opt/homebrew/bin/cloudflared",
            "/usr/local/bin/cloudflared"
        ]
        
        for path in candidatePaths {
            if fm.isExecutableFile(atPath: path) {
                return path
            }
        }
        
        // 3. System PATH check
        let whichProcess = Process()
        let whichPipe = Pipe()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["cloudflared"]
        whichProcess.standardOutput = whichPipe
        try? whichProcess.run()
        whichProcess.waitUntilExit()
        
        let data = whichPipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty, fm.isExecutableFile(atPath: path) {
            return path
        }
        
        return nil
    }
    
    public func startTunnel(port: UInt16) {
        guard process == nil else { return }
        
        guard let binaryPath = findCloudflaredBinary() else {
            self.status = .failed(error: "cloudflared binary not found. Please install via 'brew install cloudflared' or place in bin/ folder.")
            self.appendLog("❌ cloudflared binary not found.\n")
            return
        }
        
        self.status = .starting
        self.isRunning = true
        self.publicUrl = nil
        self.appendLog("⏳ Starting Cloudflare Tunnel on http://127.0.0.1:\(port)...\n")
        
        let proc = Process()
        let pipe = Pipe()
        
        proc.executableURL = URL(fileURLWithPath: binaryPath)
        proc.arguments = ["tunnel", "--url", "http://127.0.0.1:\(port)", "--no-autoupdate"]
        proc.standardOutput = pipe
        proc.standardError = pipe
        
        self.process = proc
        self.stdoutPipe = pipe
        
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { [weak self] h in
            let data = h.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.appendLog(text)
                
                // Parse for trycloudflare.com URL
                if self.publicUrl == nil {
                    if let url = self.extractTunnelUrl(from: text) {
                        self.publicUrl = url
                        self.status = .connected(url: url)
                        self.appendLog("🚀 Tunnel Online: \(url)\n")
                    }
                }
            }
        }
        
        proc.terminationHandler = { [weak self] p in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isRunning = false
                self.process = nil
                self.publicUrl = nil
                if case .connected = self.status {
                    self.status = .stopped
                }
                self.appendLog("🛑 Tunnel process terminated (code \(p.terminationStatus))\n")
            }
        }
        
        do {
            try proc.run()
        } catch {
            self.status = .failed(error: error.localizedDescription)
            self.isRunning = false
            self.process = nil
            self.appendLog("❌ Failed to start cloudflared: \(error.localizedDescription)\n")
        }
    }
    
    public func stopTunnel() {
        guard let proc = process else { return }
        self.appendLog("Stopping tunnel...\n")
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        proc.terminate()
        self.process = nil
        self.publicUrl = nil
        self.status = .stopped
        self.isRunning = false
    }
    
    private func extractTunnelUrl(from text: String) -> String? {
        let pattern = "https://[a-zA-Z0-9-]+\\.trycloudflare\\.com"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(location: 0, length: text.utf16.count)
        if let match = regex.firstMatch(in: text, range: range),
           let matchRange = Range(match.range, in: text) {
            return String(text[matchRange])
        }
        return nil
    }
    
    private func appendLog(_ text: String) {
        self.tunnelLogs.append(text)
        if self.tunnelLogs.count > 40_000 {
            self.tunnelLogs = String(self.tunnelLogs.suffix(20_000))
        }
    }
}
