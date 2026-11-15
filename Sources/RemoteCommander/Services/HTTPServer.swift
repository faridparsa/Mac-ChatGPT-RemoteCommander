import Foundation
import Network

private final class ConnectionReader: @unchecked Sendable {
    let connection: NWConnection
    let onComplete: @Sendable (Data) -> Void
    private let lock = NSLock()
    private var buffer = Data()
    
    init(connection: NWConnection, onComplete: @escaping @Sendable (Data) -> Void) {
        self.connection = connection
        self.onComplete = onComplete
    }
    
    func start() {
        readNext()
    }
    
    private func readNext() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self.lock.lock()
                self.buffer.append(data)
                let current = self.buffer
                self.lock.unlock()
                
                if let request = HTTPRequest(data: current) {
                    if let contentLengthStr = request.headers["content-length"],
                       let expected = Int(contentLengthStr.trimmingCharacters(in: .whitespaces)) {
                        if request.body.count < expected {
                            self.readNext()
                            return
                        }
                    }
                    self.onComplete(current)
                    return
                }
            }
            
            if isComplete || error != nil {
                self.lock.lock()
                let current = self.buffer
                self.lock.unlock()
                if !current.isEmpty {
                    self.onComplete(current)
                } else {
                    self.connection.cancel()
                }
            } else {
                self.readNext()
            }
        }
    }
}

public class HTTPServer: @unchecked Sendable {
    private var listener: NWListener?
    private let port: UInt16
    private weak var commandManager: CommandManager?
    private weak var settings: AppSettings?
    private var isRunning: Bool = false
    
    public init(port: UInt16, commandManager: CommandManager, settings: AppSettings) {
        self.port = port
        self.commandManager = commandManager
        self.settings = settings
    }
    
    public func start() throws {
        guard !isRunning else { return }
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw NSError(domain: "HTTPServer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid port"])
        }
        
        let newListener = try NWListener(using: params, on: nwPort)
        self.listener = newListener
        
        newListener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("🟢 HTTPServer listening on port \(self.port)")
            case .failed(let error):
                print("🔴 HTTPServer failed: \(error)")
            case .cancelled:
                print("⚪️ HTTPServer stopped")
            default:
                break
            }
        }
        
        newListener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        
        newListener.start(queue: .global(qos: .userInitiated))
        self.isRunning = true
    }
    
    public func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        let reader = ConnectionReader(connection: connection) { [weak self] rawData in
            guard let self = self, let request = HTTPRequest(data: rawData) else {
                connection.cancel()
                return
            }
            Task {
                let response = await self.processRequest(request)
                self.sendResponse(response, on: connection)
            }
        }
        reader.start()
    }
    
    private func sendResponse(_ response: HTTPResponse, on connection: NWConnection) {
        let rawData = response.toData()
        connection.send(content: rawData, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    private func processRequest(_ req: HTTPRequest) async -> HTTPResponse {
        // Handle CORS Preflight
        if req.method == "OPTIONS" {
            return HTTPResponse.corsOk()
        }
        
        let path = req.path
        
        // 1. Health / Status
        if path == "/health" || path == "/status" || path == "/" {
            let json = """
            {"status":"ok","app":"RemoteCommander","version":"1.0.0","uptime":"online"}
            """
            return HTTPResponse.json(body: json)
        }
        
        // 2. OpenAPI JSON Schema for Custom GPT
        if path == "/openapi.json" || path == "/schema.json" {
            return HTTPResponse.json(body: generateOpenAPISpec())
        }
        
        // 3. MCP SSE endpoint handshake
        if path == "/sse" && req.method == "GET" {
            let sseBody = "event: endpoint\ndata: /mcp\n\n"
            return HTTPResponse(
                statusCode: 200,
                headers: [
                    "Content-Type": "text/event-stream",
                    "Cache-Control": "no-cache",
                    "Connection": "keep-alive",
                    "Access-Control-Allow-Origin": "*"
                ],
                body: sseBody.data(using: .utf8) ?? Data()
            )
        }
        
        // Check Authentication for Execution and Tools
        if let settings = self.settings {
            let expectedToken = await MainActor.run { settings.apiToken }
            let authHeader = req.headers["authorization"] ?? ""
            let valid = authHeader == "Bearer \(expectedToken)" || authHeader == expectedToken
            
            // Allow without token ONLY if settings token is empty (for testing)
            if !expectedToken.isEmpty && !valid {
                let err = """
                {"error":"Unauthorized: Missing or invalid Bearer token. Please provide 'Authorization: Bearer <token>'."}
                """
                return HTTPResponse.json(body: err, statusCode: 401)
            }
        }
        
        // 4. REST Execute Command (/api/execute)
        if path == "/api/execute" && req.method == "POST" {
            guard let cm = self.commandManager, let st = self.settings else {
                return HTTPResponse.json(body: "{\"error\":\"Server internal error\"}", statusCode: 500)
            }
            
            do {
                guard let jsonObj = try JSONSerialization.jsonObject(with: req.body) as? [String: Any],
                      let command = jsonObj["command"] as? String else {
                    return HTTPResponse.json(body: "{\"error\":\"Invalid JSON: 'command' string is required.\"}", statusCode: 400)
                }
                
                let workdir = jsonObj["workdir"] as? String
                let source = (jsonObj["source"] as? String) ?? "ChatGPT Web"
                
                let result = await cm.handleIncomingCommand(
                    command: command,
                    workingDir: workdir,
                    source: source,
                    settings: st
                )
                
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(result)
                return HTTPResponse.json(data: data)
            } catch {
                return HTTPResponse.json(body: "{\"error\":\"Failed to parse request JSON: \(error.localizedDescription)\"}", statusCode: 400)
            }
        }
        
        // 5. Model Context Protocol (MCP) JSON-RPC (/mcp)
        if (path == "/mcp" || path == "/messages") && req.method == "POST" {
            return await handleMCPJsonRpc(req)
        }
        
        return HTTPResponse.notFound()
    }
    
    private func handleMCPJsonRpc(_ req: HTTPRequest) async -> HTTPResponse {
        guard let cm = self.commandManager, let st = self.settings else {
            return HTTPResponse.json(body: "{\"error\":\"Server unready\"}", statusCode: 500)
        }
        
        guard let jsonObj = (try? JSONSerialization.jsonObject(with: req.body)) as? [String: Any],
              let method = jsonObj["method"] as? String else {
            return HTTPResponse.json(body: "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32600,\"message\":\"Invalid Request\"},\"id\":null}", statusCode: 400)
        }
        
        let id = jsonObj["id"] // can be Int or String
        
        switch method {
        case "initialize":
            let resp: [String: Any] = [
                "jsonrpc": "2.0",
                "id": id as Any,
                "result": [
                    "protocolVersion": "2024-11-05",
                    "capabilities": [
                        "tools": [
                            "listChanged": false
                        ]
                    ],
                    "serverInfo": [
                        "name": "RemoteCommander",
                        "version": "1.0.0"
                    ]
                ]
            ]
            let data = (try? JSONSerialization.data(withJSONObject: resp)) ?? Data()
            return HTTPResponse.json(data: data)
            
        case "notifications/initialized":
            // Acknowledgement notification
            let resp: [String: Any] = [
                "jsonrpc": "2.0",
                "result": [:]
            ]
            let data = (try? JSONSerialization.data(withJSONObject: resp)) ?? Data()
            return HTTPResponse.json(data: data)
            
        case "tools/list":
            let tools: [[String: Any]] = [
                [
                    "name": "execute_command",
                    "description": "Execute a shell command on the user's Mac terminal (e.g. ls, git, npm, python, brew). Pops up an approval prompt on user's screen.",
                    "inputSchema": [
                        "type": "object",
                        "properties": [
                            "command": [
                                "type": "string",
                                "description": "The exact shell command to run on Mac"
                            ],
                            "workdir": [
                                "type": "string",
                                "description": "Optional working directory"
                            ]
                        ],
                        "required": ["command"]
                    ]
                ]
            ]
            let resp: [String: Any] = [
                "jsonrpc": "2.0",
                "id": id as Any,
                "result": [
                    "tools": tools
                ]
            ]
            let data = (try? JSONSerialization.data(withJSONObject: resp)) ?? Data()
            return HTTPResponse.json(data: data)
            
        case "tools/call":
            guard let params = jsonObj["params"] as? [String: Any],
                  let toolName = params["name"] as? String,
                  let args = params["arguments"] as? [String: Any] else {
                return HTTPResponse.json(body: "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32602,\"message\":\"Invalid params\"},\"id\":null}", statusCode: 400)
            }
            
            if toolName == "execute_command" {
                let command = (args["command"] as? String) ?? ""
                let workdir = args["workdir"] as? String
                
                let result = await cm.handleIncomingCommand(
                    command: command,
                    workingDir: workdir,
                    source: "ChatGPT MCP",
                    settings: st
                )
                
                var outputText = result.stdout
                if !result.stderr.isEmpty {
                    if !outputText.isEmpty { outputText += "\n" }
                    outputText += "[stderr]:\n" + result.stderr
                }
                if let err = result.error {
                    outputText += "\n[error]: \(err)"
                }
                
                let resp: [String: Any] = [
                    "jsonrpc": "2.0",
                    "id": id as Any,
                    "result": [
                        "content": [
                            [
                                "type": "text",
                                "text": outputText.isEmpty ? "(Command produced no output, exit code: \(result.exitCode))" : outputText
                            ]
                        ],
                        "isError": result.exitCode != 0
                    ]
                ]
                let data = (try? JSONSerialization.data(withJSONObject: resp)) ?? Data()
                return HTTPResponse.json(data: data)
            } else {
                return HTTPResponse.json(body: "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32601,\"message\":\"Method not found\"},\"id\":null}", statusCode: 404)
            }
            
        default:
            return HTTPResponse.json(body: "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32601,\"message\":\"Unsupported method: \(method)\"},\"id\":null}", statusCode: 404)
        }
    }
    
    public func generateOpenAPISpec(serverUrl: String = "https://your-tunnel-url.trycloudflare.com") -> String {
        return """
        {
          "openapi": "3.1.0",
          "info": {
            "title": "RemoteCommander Mac Terminal",
            "description": "Execute shell commands on your Mac directly from ChatGPT with native approval prompts.",
            "version": "1.0.0"
          },
          "servers": [
            {
              "url": "\(serverUrl)"
            }
          ],
          "paths": {
            "/api/execute": {
              "post": {
                "summary": "Run a shell command on Mac terminal",
                "description": "Executes a command on the user's Mac after user approval in the native app.",
                "operationId": "executeCommand",
                "requestBody": {
                  "required": true,
                  "content": {
                    "application/json": {
                      "schema": {
                        "type": "object",
                        "properties": {
                          "command": {
                            "type": "string",
                            "description": "The exact shell command to run on the Mac (e.g. ls -la, git status, cargo build, npm test)"
                          },
                          "workdir": {
                            "type": "string",
                            "description": "Optional working directory"
                          }
                        },
                        "required": ["command"]
                      }
                    }
                  }
                },
                "responses": {
                  "200": {
                    "description": "Command execution output",
                    "content": {
                      "application/json": {
                        "schema": {
                          "type": "object",
                          "properties": {
                            "success": { "type": "boolean" },
                            "stdout": { "type": "string" },
                            "stderr": { "type": "string" },
                            "exitCode": { "type": "integer" },
                            "durationMs": { "type": "integer" },
                            "error": { "type": "string" }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "components": {
            "securitySchemes": {
              "BearerAuth": {
                "type": "http",
                "scheme": "bearer"
              }
            }
          },
          "security": [
            {
              "BearerAuth": []
            }
          ]
        }
        """
    }
}

// MARK: - HTTP Parser & Response

public struct HTTPRequest: Sendable {
    public let method: String
    public let path: String
    public let headers: [String: String]
    public let body: Data
    
    public init?(data: Data) {
        guard let delimiterRange = data.range(of: Data("\r\n\r\n".utf8)) else {
            return nil
        }
        
        let headerData = data.subdata(in: 0..<delimiterRange.lowerBound)
        let bodyData = data.subdata(in: delimiterRange.upperBound..<data.count)
        
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            return nil
        }
        
        let lines = headerString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        
        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return nil }
        
        self.method = parts[0].uppercased()
        // Extract path without query parameters for routing
        let rawPath = parts[1]
        self.path = rawPath.components(separatedBy: "?").first ?? rawPath
        
        var parsedHeaders: [String: String] = [:]
        for line in lines.dropFirst() {
            let headerParts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
            if headerParts.count == 2 {
                let key = headerParts[0].trimmingCharacters(in: .whitespaces).lowercased()
                let val = headerParts[1].trimmingCharacters(in: .whitespaces)
                parsedHeaders[key] = val
            }
        }
        self.headers = parsedHeaders
        self.body = bodyData
    }
}

public struct HTTPResponse: Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data
    
    public init(statusCode: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
    
    public static func json(body: String, statusCode: Int = 200) -> HTTPResponse {
        let data = body.data(using: .utf8) ?? Data()
        return HTTPResponse(
            statusCode: statusCode,
            headers: [
                "Content-Type": "application/json; charset=utf-8",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
                "Access-Control-Allow-Headers": "Authorization, Content-Type, Accept"
            ],
            body: data
        )
    }
    
    public static func json(data: Data, statusCode: Int = 200) -> HTTPResponse {
        return HTTPResponse(
            statusCode: statusCode,
            headers: [
                "Content-Type": "application/json; charset=utf-8",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
                "Access-Control-Allow-Headers": "Authorization, Content-Type, Accept"
            ],
            body: data
        )
    }
    
    public static func corsOk() -> HTTPResponse {
        return HTTPResponse(
            statusCode: 204,
            headers: [
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
                "Access-Control-Allow-Headers": "Authorization, Content-Type, Accept",
                "Access-Control-Max-Age": "86400"
            ],
            body: Data()
        )
    }
    
    public static func notFound() -> HTTPResponse {
        let data = "{\"error\":\"Not Found\"}".data(using: .utf8) ?? Data()
        return HTTPResponse(
            statusCode: 404,
            headers: [
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            ],
            body: data
        )
    }
    
    public func toData() -> Data {
        let statusText = HTTPResponse.statusText(for: statusCode)
        var head = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
        var finalHeaders = headers
        finalHeaders["Content-Length"] = "\(body.count)"
        finalHeaders["Connection"] = "close"
        
        for (k, v) in finalHeaders {
            head += "\(k): \(v)\r\n"
        }
        head += "\r\n"
        
        var data = head.data(using: .utf8) ?? Data()
        data.append(body)
        return data
    }
    
    private static func statusText(for code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 204: return "No Content"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        default: return "Response"
        }
    }
}
