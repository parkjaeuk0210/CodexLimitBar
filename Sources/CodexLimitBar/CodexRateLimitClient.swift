import Darwin
import Foundation

final class CodexRateLimitClient {
    func fetch() async throws -> RateLimitsReadResult {
        guard let codexPath = Self.findCodexExecutable() else {
            throw LimitFetchError.codexNotFound
        }

        let port = try Self.findFreePort()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: codexPath)
        process.arguments = ["app-server", "--listen", "ws://127.0.0.1:\(port)"]
        process.environment = Self.processEnvironment()

        let nullHandle = FileHandle(forWritingAtPath: "/dev/null")
        process.standardOutput = nullHandle
        process.standardError = nullHandle

        try process.run()
        defer {
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
            try? nullHandle?.close()
        }

        try await waitUntilReady(port: port)
        return try await readRateLimits(port: port)
    }

    private func waitUntilReady(port: UInt16) async throws {
        let url = URL(string: "http://127.0.0.1:\(port)/readyz")!
        for _ in 0..<40 {
            do {
                let (_, response) = try await URLSession.shared.data(from: url)
                if (response as? HTTPURLResponse)?.statusCode == 200 {
                    return
                }
            } catch {
                // The server is still starting; try again after a short sleep.
            }
            try await Task.sleep(nanoseconds: 150_000_000)
        }
        throw LimitFetchError.appServerNotReady
    }

    private func readRateLimits(port: UInt16) async throws -> RateLimitsReadResult {
        let url = URL(string: "ws://127.0.0.1:\(port)")!
        let webSocket = URLSession.shared.webSocketTask(with: url)
        webSocket.resume()
        defer { webSocket.cancel(with: .goingAway, reason: nil) }

        try await sendJSON([
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": [
                "clientInfo": [
                    "name": "CodexLimitBar",
                    "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.1"
                ],
                "capabilities": [
                    "experimentalApi": true
                ]
            ]
        ], over: webSocket)

        try await sendJSON([
            "jsonrpc": "2.0",
            "id": 2,
            "method": "account/rateLimits/read",
            "params": NSNull()
        ], over: webSocket)

        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            let message = try await webSocket.receive()
            let data: Data
            switch message {
            case .data(let payload):
                data = payload
            case .string(let text):
                data = Data(text.utf8)
            @unknown default:
                continue
            }

            guard
                let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let id = object["id"] as? Int
            else {
                continue
            }

            if let errorObject = object["error"] as? [String: Any] {
                let message = errorObject["message"] as? String ?? "unknown JSON-RPC error"
                throw LimitFetchError.rpcError(message)
            }

            guard id == 2 else { continue }
            guard let resultObject = object["result"] else {
                throw LimitFetchError.malformedResponse
            }

            let resultData = try JSONSerialization.data(withJSONObject: resultObject)
            return try JSONDecoder().decode(RateLimitsReadResult.self, from: resultData)
        }

        throw LimitFetchError.malformedResponse
    }

    private func sendJSON(_ object: [String: Any], over webSocket: URLSessionWebSocketTask) async throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        let text = String(decoding: data, as: UTF8.self)
        try await webSocket.send(.string(text))
    }

    private static func processEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let defaultPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = environment["PATH"].map { "\($0):\(defaultPath)" } ?? defaultPath
        environment["TERM"] = environment["TERM"] ?? "dumb"
        return environment
    }

    private static func findCodexExecutable() -> String? {
        let candidates = [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "/usr/bin/codex"
        ]

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", "codex"]
        process.environment = processEnvironment()

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle(forWritingAtPath: "/dev/null")

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let output = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            return path.isEmpty ? nil : path
        } catch {
            return nil
        }
    }

    private static func findFreePort() throws -> UInt16 {
        let descriptor = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard descriptor >= 0 else { throw LimitFetchError.noFreePort }
        defer { close(descriptor) }

        var reuse: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                bind(descriptor, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else { throw LimitFetchError.noFreePort }

        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                getsockname(descriptor, sockaddrPointer, &length)
            }
        }
        guard nameResult == 0 else { throw LimitFetchError.noFreePort }

        return UInt16(bigEndian: address.sin_port)
    }
}
