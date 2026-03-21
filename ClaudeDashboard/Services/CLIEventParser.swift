import Foundation

struct CLIEventParser {
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    func parse(line: String) throws -> CLIEvent {
        guard let data = line.data(using: .utf8) else {
            throw CLIEventParserError.invalidData
        }
        return try decoder.decode(CLIEvent.self, from: data)
    }

    func parseMultiple(lines: String) throws -> [CLIEvent] {
        try lines
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { try parse(line: $0) }
    }
}

enum CLIEventParserError: Error {
    case invalidData
}
