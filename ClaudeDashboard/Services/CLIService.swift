import Foundation

@MainActor @Observable
final class CLIService: @unchecked Sendable {
    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private let parser = CLIEventParser()

    private(set) var isRunning = false
    private(set) var currentSessionId: String?

    var onEvent: ((CLIEvent) -> Void)?
    var onRawOutput: ((String) -> Void)?
    var onError: ((String) -> Void)?
    var onProcessExit: ((Int32) -> Void)?

    private static let claudePath = "/Users/alexstanage/.local/bin/claude"

    /// Thread-safe line buffer for partial stdout chunks
    private final class LineBuffer: @unchecked Sendable {
        var value = ""
    }

    /// Send a message by spawning a new `claude --print` process.
    func sendMessage(_ text: String, model: String? = nil, effort: String? = nil) {
        stop()

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: Self.claudePath)

        var args = ["--print", "--output-format", "stream-json", "--verbose"]
        if let model { args += ["--model", model] }
        if let effort { args += ["--effort", effort] }
        if let sessionId = currentSessionId {
            args += ["--resume", sessionId]
        }
        args.append(text)

        process.arguments = args
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let parser = self.parser
        let buffer = LineBuffer()
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }

            let combined = buffer.value + chunk
            var lines = combined.components(separatedBy: "\n")
            buffer.value = lines.removeLast()

            let parsedEvents: [(event: CLIEvent, raw: String)] = lines.compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                guard let event = try? parser.parse(line: trimmed) else { return nil }
                return (event, trimmed)
            }

            Task { @MainActor [weak self] in
                self?.onRawOutput?(chunk)
                for (event, raw) in parsedEvents {
                    // Extract session_id from init event
                    if event.type == "system", raw.contains("\"subtype\":\"init\"") {
                        self?.extractSessionId(from: raw)
                    }
                    self?.onEvent?(event)
                }
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in
                self?.onError?(output)
                self?.onRawOutput?(output)
            }
        }

        process.terminationHandler = { [weak self] proc in
            let status = proc.terminationStatus
            // Flush remaining buffer
            let remaining = buffer.value
            buffer.value = ""
            Task { @MainActor [weak self] in
                if !remaining.isEmpty {
                    let trimmed = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty, let event = try? parser.parse(line: trimmed) {
                        if event.type == "system", trimmed.contains("\"subtype\":\"init\"") {
                            self?.extractSessionId(from: trimmed)
                        }
                        self?.onEvent?(event)
                    }
                }
                self?.isRunning = false
                self?.onProcessExit?(status)
            }
        }

        do {
            try process.run()
            self.process = process
            self.stdoutPipe = stdoutPipe
            self.stderrPipe = stderrPipe
            self.isRunning = true
        } catch {
            onError?("Failed to launch claude: \(error.localizedDescription)")
        }
    }

    private func extractSessionId(from line: String) {
        if let data = line.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let sessionId = json["session_id"] as? String {
            self.currentSessionId = sessionId
        }
    }

    func newSession() {
        stop()
        currentSessionId = nil
    }

    func stop() {
        guard let process, process.isRunning else {
            cleanup()
            return
        }
        process.terminate()
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [weak self] in
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
            Task { @MainActor [weak self] in
                self?.cleanup()
            }
        }
    }

    private func cleanup() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil
        stdoutPipe = nil
        stderrPipe = nil
        isRunning = false
    }
}
