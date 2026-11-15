import Foundation

public struct ProcessResult: Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
    public let duration: TimeInterval
    public let errorMessage: String?
}

private final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    
    func append(_ chunk: Data) {
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }
    
    func string() -> String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

public actor ProcessRunner {
    public init() {}
    
    public func execute(
        command: String,
        workingDirectory: String,
        shell: String = "/bin/zsh",
        timeout: TimeInterval = 60.0,
        onOutput: (@Sendable (String, Bool) -> Void)? = nil // (text, isStderr)
    ) async -> ProcessResult {
        let startTime = Date()
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-c", command]
        
        // Ensure working directory exists, fallback to home directory
        let fm = FileManager.default
        let currentDir = fm.fileExists(atPath: workingDirectory) ? workingDirectory : fm.homeDirectoryForCurrentUser.path
        process.currentDirectoryURL = URL(fileURLWithPath: currentDir)
        
        // Build robust environment including Homebrew, local, and user binaries
        var env = ProcessInfo.processInfo.environment
        let extraPaths = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            NSString(string: "~/.cargo/bin").expandingTildeInPath
        ]
        let currentPath = env["PATH"] ?? ""
        env["PATH"] = (extraPaths + [currentPath]).joined(separator: ":")
        env["LANG"] = "en_US.UTF-8"
        env["LC_ALL"] = "en_US.UTF-8"
        env["TERM"] = "xterm-256color"
        process.environment = env
        
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        let stdoutBuffer = OutputBuffer()
        let stderrBuffer = OutputBuffer()
        
        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading
        
        stdoutHandle.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty {
                stdoutBuffer.append(chunk)
                if let str = String(data: chunk, encoding: .utf8) {
                    onOutput?(str, false)
                }
            }
        }
        
        stderrHandle.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty {
                stderrBuffer.append(chunk)
                if let str = String(data: chunk, encoding: .utf8) {
                    onOutput?(str, true)
                }
            }
        }
        
        do {
            try process.run()
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            stdoutHandle.readabilityHandler = nil
            stderrHandle.readabilityHandler = nil
            return ProcessResult(
                stdout: "",
                stderr: "",
                exitCode: -1,
                duration: duration,
                errorMessage: "Failed to spawn process: \(error.localizedDescription)"
            )
        }
        
        // Handle timeout asynchronously
        let executionTask = Task.detached { () -> Int32 in
            process.waitUntilExit()
            return process.terminationStatus
        }
        
        var exitCode: Int32 = 0
        var errorMessage: String? = nil
        
        do {
            exitCode = try await withThrowingTaskGroup(of: Int32.self) { group in
                group.addTask {
                    return await executionTask.value
                }
                
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw CancellationError()
                }
                
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
        } catch is CancellationError {
            process.terminate()
            exitCode = -1
            errorMessage = "Command timed out after \(Int(timeout)) seconds"
        } catch {
            exitCode = process.terminationStatus
        }
        
        stdoutHandle.readabilityHandler = nil
        stderrHandle.readabilityHandler = nil
        
        // Read any remaining data in pipes
        let remainingStdout = stdoutHandle.readDataToEndOfFile()
        if !remainingStdout.isEmpty {
            stdoutBuffer.append(remainingStdout)
        }
        let remainingStderr = stderrHandle.readDataToEndOfFile()
        if !remainingStderr.isEmpty {
            stderrBuffer.append(remainingStderr)
        }
        
        let stdoutStr = stdoutBuffer.string()
        let stderrStr = stderrBuffer.string()
        let duration = Date().timeIntervalSince(startTime)
        
        return ProcessResult(
            stdout: stdoutStr,
            stderr: stderrStr,
            exitCode: exitCode,
            duration: duration,
            errorMessage: errorMessage
        )
    }
}
