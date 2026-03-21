import Foundation

@MainActor @Observable
final class CLIService {
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private let parser = CLIEventParser()

    private(set) var isRunning = false
    private(set) var currentSessionId: String?

    var onEvent: ((CLIEvent) -> Void)?
    var onRawOutput: ((String) -> Void)?
    var onError: ((String) -> Void)?
    var onProcessExit: ((Int32) -> Void)?

    func startSession(resume sessionId: String? = nil) throws {
        stop()

        let process = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        var args = ["claude", "--print", "--output-format", "stream-json", "--input-format", "stream-json"]
        if let sessionId {
            args += ["--resume", sessionId]
            self.currentSessionId = sessionId
        }
        process.arguments = args
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let parser = self.parser
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }

            let events: [CLIEvent] = output.split(separator: "\n").map(String.init).compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return try? parser.parse(line: trimmed)
            }

            Task { @MainActor [weak self] in
                self?.onRawOutput?(output)
                for event in events {
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
            Task { @MainActor [weak self] in
                self?.isRunning = false
                self?.onProcessExit?(status)
            }
        }

        try process.run()
        self.process = process
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
        self.isRunning = true
    }

    func send(message: String) {
        guard isRunning, let stdinPipe else { return }
        let jsonMessage: [String: Any] = [
            "type": "user",
            "message": ["role": "user", "content": [["type": "text", "text": message]]]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: jsonMessage),
              var jsonStr = String(data: data, encoding: .utf8) else { return }
        jsonStr += "\n"
        stdinPipe.fileHandleForWriting.write(jsonStr.data(using: .utf8)!)
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
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
        isRunning = false
    }
}
