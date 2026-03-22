import AppKit

struct SyntaxHighlighter {

    // MARK: - Font & Colors

    nonisolated(unsafe) private static let monoFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    private static let defaultColor  = NSColor(calibratedRed: 0.78, green: 0.78, blue: 0.80, alpha: 1)  // light gray
    private static let keywordColor  = NSColor(calibratedRed: 0.68, green: 0.51, blue: 0.85, alpha: 1)  // purple
    private static let stringColor   = NSColor(calibratedRed: 0.87, green: 0.36, blue: 0.36, alpha: 1)  // red
    private static let commentColor  = NSColor(calibratedRed: 0.55, green: 0.55, blue: 0.57, alpha: 1)  // gray
    private static let numberColor   = NSColor(calibratedRed: 0.86, green: 0.78, blue: 0.40, alpha: 1)  // yellow
    private static let typeColor     = NSColor(calibratedRed: 0.40, green: 0.80, blue: 0.85, alpha: 1)  // cyan

    // MARK: - Regex Patterns

    static let slashCommentPattern = try! NSRegularExpression(pattern: "//[^\n]*")
    static let hashCommentPattern  = try! NSRegularExpression(pattern: "#[^\n]*")
    static let multiLineCommentPattern = try! NSRegularExpression(pattern: "/\\*[\\s\\S]*?\\*/", options: .dotMatchesLineSeparators)
    static let doubleQuoteStringPattern = try! NSRegularExpression(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"")
    static let singleQuoteStringPattern = try! NSRegularExpression(pattern: "'(?:[^'\\\\]|\\\\.)*'")
    static let numberPattern = try! NSRegularExpression(pattern: "\\b\\d+(\\.\\d+)?\\b")
    static let wordPattern = try! NSRegularExpression(pattern: "\\b[a-zA-Z_][a-zA-Z0-9_]*(?:\\?)?\\b")
    static let typePattern = try! NSRegularExpression(pattern: "\\b[A-Z][a-zA-Z0-9_]*\\b")

    // MARK: - Language Aliases

    static let languageAliases: [String: String] = [
        "js": "javascript",
        "ts": "typescript",
        "sh": "shell",
        "bash": "shell",
        "zsh": "shell",
        "cpp": "c",
        "h": "c",
        "hpp": "c",
        "py": "python",
        "rs": "rust",
        "yml": "yaml",
        "rb": "ruby",
        "kt": "kotlin",
    ]

    // MARK: - Language Keyword Sets

    static let swiftKeywords: Set<String> = [
        "let", "var", "func", "class", "struct", "enum", "protocol", "extension",
        "import", "return", "if", "else", "guard", "switch", "case", "default",
        "for", "while", "repeat", "break", "continue", "in", "where", "throw",
        "throws", "try", "catch", "do", "as", "is", "self", "Self", "super",
        "init", "deinit", "subscript", "typealias", "associatedtype", "static",
        "override", "mutating", "nonmutating", "lazy", "weak", "unowned",
        "private", "fileprivate", "internal", "public", "open", "final",
        "async", "await", "actor", "nonisolated", "isolated", "sending",
        "true", "false", "nil", "some", "any",
    ]

    static let pythonKeywords: Set<String> = [
        "def", "class", "if", "elif", "else", "for", "while", "return", "import",
        "from", "as", "try", "except", "finally", "raise", "with", "yield",
        "lambda", "pass", "break", "continue", "and", "or", "not", "in", "is",
        "True", "False", "None", "global", "nonlocal", "assert", "del", "async",
        "await",
    ]

    static let javascriptKeywords: Set<String> = [
        "const", "let", "var", "function", "return", "if", "else", "for", "while",
        "do", "switch", "case", "default", "break", "continue", "throw", "try",
        "catch", "finally", "new", "delete", "typeof", "instanceof", "in", "of",
        "class", "extends", "super", "this", "import", "export", "from", "as",
        "async", "await", "yield", "true", "false", "null", "undefined", "void",
        "static", "get", "set",
    ]

    static let typescriptKeywords: Set<String> = javascriptKeywords.union([
        "type", "interface", "enum", "namespace", "declare", "readonly",
        "abstract", "implements", "private", "protected", "public", "as",
        "keyof", "never", "unknown", "any", "string", "number", "boolean",
    ])

    static let goKeywords: Set<String> = [
        "func", "package", "import", "return", "if", "else", "for", "range",
        "switch", "case", "default", "break", "continue", "go", "defer",
        "select", "chan", "map", "struct", "interface", "type", "var", "const",
        "true", "false", "nil", "make", "new", "len", "cap", "append",
    ]

    static let rustKeywords: Set<String> = [
        "fn", "let", "mut", "const", "static", "struct", "enum", "impl", "trait",
        "use", "mod", "pub", "crate", "super", "self", "Self", "return", "if",
        "else", "match", "for", "while", "loop", "break", "continue", "where",
        "as", "in", "ref", "move", "async", "await", "dyn", "type", "unsafe",
        "true", "false",
    ]

    static let shellKeywords: Set<String> = [
        "if", "then", "else", "elif", "fi", "for", "while", "do", "done",
        "case", "esac", "function", "return", "exit", "echo", "export",
        "source", "local", "readonly", "set", "unset", "shift", "true", "false",
        "in",
    ]

    static let sqlKeywords: Set<String> = [
        "SELECT", "FROM", "WHERE", "INSERT", "INTO", "VALUES", "UPDATE", "SET",
        "DELETE", "CREATE", "TABLE", "DROP", "ALTER", "INDEX", "JOIN", "LEFT",
        "RIGHT", "INNER", "OUTER", "ON", "AND", "OR", "NOT", "NULL", "IS",
        "IN", "LIKE", "BETWEEN", "ORDER", "BY", "GROUP", "HAVING", "LIMIT",
        "DISTINCT", "AS", "UNION", "ALL", "EXISTS", "COUNT", "SUM", "AVG",
        "MAX", "MIN", "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "CASCADE",
        "TRUE", "FALSE",
        // lowercase variants
        "select", "from", "where", "insert", "into", "values", "update", "set",
        "delete", "create", "table", "drop", "alter", "index", "join", "left",
        "right", "inner", "outer", "on", "and", "or", "not", "null", "is",
        "in", "like", "between", "order", "by", "group", "having", "limit",
        "distinct", "as", "union", "all", "exists", "count", "sum", "avg",
        "max", "min", "primary", "key", "foreign", "references", "cascade",
        "true", "false",
    ]

    static let htmlKeywords: Set<String> = [
        "html", "head", "body", "div", "span", "p", "a", "img", "ul", "ol",
        "li", "table", "tr", "td", "th", "form", "input", "button", "script",
        "style", "link", "meta", "title", "h1", "h2", "h3", "h4", "h5", "h6",
        "section", "article", "nav", "header", "footer", "main", "aside",
    ]

    static let cssKeywords: Set<String> = [
        "color", "background", "margin", "padding", "border", "font", "display",
        "position", "top", "left", "right", "bottom", "width", "height", "flex",
        "grid", "align", "justify", "content", "items", "none", "block", "inline",
        "absolute", "relative", "fixed", "sticky", "important", "inherit",
        "initial", "auto",
    ]

    static let javaKeywords: Set<String> = [
        "class", "interface", "enum", "extends", "implements", "import",
        "package", "public", "private", "protected", "static", "final",
        "abstract", "synchronized", "volatile", "transient", "native",
        "new", "return", "if", "else", "for", "while", "do", "switch",
        "case", "default", "break", "continue", "throw", "throws", "try",
        "catch", "finally", "this", "super", "void", "int", "long", "double",
        "float", "boolean", "char", "byte", "short", "null", "true", "false",
        "instanceof",
    ]

    static let kotlinKeywords: Set<String> = [
        "fun", "val", "var", "class", "object", "interface", "enum", "data",
        "sealed", "abstract", "open", "override", "private", "protected",
        "public", "internal", "return", "if", "else", "when", "for", "while",
        "do", "break", "continue", "throw", "try", "catch", "finally",
        "import", "package", "as", "is", "in", "null", "true", "false",
        "this", "super", "companion", "suspend", "lateinit", "by", "init",
    ]

    static let rubyKeywords: Set<String> = [
        "def", "end", "class", "module", "if", "elsif", "else", "unless",
        "while", "until", "for", "do", "begin", "rescue", "ensure", "raise",
        "return", "yield", "block_given?", "self", "super", "nil", "true",
        "false", "and", "or", "not", "in", "then", "require", "include",
        "attr_reader", "attr_writer", "attr_accessor", "puts", "print",
    ]

    static let jsonKeywords: Set<String> = [
        "true", "false", "null",
    ]

    static let yamlKeywords: Set<String> = [
        "true", "false", "null", "yes", "no", "on", "off",
    ]

    static let cKeywords: Set<String> = [
        "auto", "break", "case", "char", "const", "continue", "default", "do",
        "double", "else", "enum", "extern", "float", "for", "goto", "if",
        "int", "long", "register", "return", "short", "signed", "sizeof",
        "static", "struct", "switch", "typedef", "union", "unsigned", "void",
        "volatile", "while", "inline", "restrict",
        // C++ additions
        "class", "namespace", "template", "typename", "public", "private",
        "protected", "virtual", "override", "final", "new", "delete", "this",
        "throw", "try", "catch", "using", "bool", "true", "false", "nullptr",
        "constexpr", "noexcept", "auto", "decltype", "include", "define",
        "ifdef", "ifndef", "endif", "pragma",
    ]

    // MARK: - Supported Languages

    static let slashCommentLanguages: Set<String> = [
        "swift", "javascript", "typescript", "go", "rust", "c", "java",
        "kotlin", "css",
    ]

    static let hashCommentLanguages: Set<String> = [
        "python", "shell", "ruby", "yaml",
    ]

    static let multiLineCommentLanguages: Set<String> = [
        "swift", "javascript", "typescript", "go", "rust", "c", "java",
        "kotlin", "css",
    ]

    static let keywordsForLanguage: [String: Set<String>] = [
        "swift": swiftKeywords,
        "python": pythonKeywords,
        "javascript": javascriptKeywords,
        "typescript": typescriptKeywords,
        "go": goKeywords,
        "rust": rustKeywords,
        "shell": shellKeywords,
        "sql": sqlKeywords,
        "html": htmlKeywords,
        "css": cssKeywords,
        "java": javaKeywords,
        "kotlin": kotlinKeywords,
        "ruby": rubyKeywords,
        "json": jsonKeywords,
        "yaml": yamlKeywords,
        "c": cKeywords,
    ]

    // MARK: - Public API

    static func highlight(_ code: String, language: String?) -> NSAttributedString {
        guard let rawLang = language else {
            return plainText(code)
        }

        let lang = resolveLanguage(rawLang)

        guard keywordsForLanguage[lang] != nil else {
            return plainText(code)
        }

        let attributed = NSMutableAttributedString(
            string: code,
            attributes: [
                .font: monoFont,
                .foregroundColor: defaultColor,
            ]
        )

        let fullRange = NSRange(location: 0, length: (code as NSString).length)

        // Track colored ranges so comments/strings take precedence
        var coloredRanges: [NSRange] = []

        // 1. Comments (language-aware)
        if slashCommentLanguages.contains(lang) {
            let matches = slashCommentPattern.matches(in: code, range: fullRange)
            for match in matches {
                attributed.addAttribute(.foregroundColor, value: commentColor, range: match.range)
                coloredRanges.append(match.range)
            }
        }

        if hashCommentLanguages.contains(lang) {
            let matches = hashCommentPattern.matches(in: code, range: fullRange)
            for match in matches {
                attributed.addAttribute(.foregroundColor, value: commentColor, range: match.range)
                coloredRanges.append(match.range)
            }
        }

        // 2. Multi-line comments (C-family only)
        if multiLineCommentLanguages.contains(lang) {
            let matches = multiLineCommentPattern.matches(in: code, range: fullRange)
            for match in matches {
                attributed.addAttribute(.foregroundColor, value: commentColor, range: match.range)
                coloredRanges.append(match.range)
            }
        }

        // 3. Strings (double and single quoted)
        let doubleQuoteMatches = doubleQuoteStringPattern.matches(in: code, range: fullRange)
        for match in doubleQuoteMatches {
            if !isOverlapping(match.range, with: coloredRanges) {
                attributed.addAttribute(.foregroundColor, value: stringColor, range: match.range)
                coloredRanges.append(match.range)
            }
        }

        let singleQuoteMatches = singleQuoteStringPattern.matches(in: code, range: fullRange)
        for match in singleQuoteMatches {
            if !isOverlapping(match.range, with: coloredRanges) {
                attributed.addAttribute(.foregroundColor, value: stringColor, range: match.range)
                coloredRanges.append(match.range)
            }
        }

        // 4. Numbers
        let numberMatches = numberPattern.matches(in: code, range: fullRange)
        for match in numberMatches {
            if !isOverlapping(match.range, with: coloredRanges) {
                attributed.addAttribute(.foregroundColor, value: numberColor, range: match.range)
                coloredRanges.append(match.range)
            }
        }

        // 5. Keywords (from language-specific sets)
        if let keywords = keywordsForLanguage[lang] {
            let wordMatches = wordPattern.matches(in: code, range: fullRange)
            for match in wordMatches {
                let word = (code as NSString).substring(with: match.range)
                if keywords.contains(word) && !isOverlapping(match.range, with: coloredRanges) {
                    attributed.addAttribute(.foregroundColor, value: keywordColor, range: match.range)
                    coloredRanges.append(match.range)
                }
            }
        }

        // 6. Type identifiers (capitalized words not already colored)
        let typeMatches = typePattern.matches(in: code, range: fullRange)
        for match in typeMatches {
            if !isOverlapping(match.range, with: coloredRanges) {
                attributed.addAttribute(.foregroundColor, value: typeColor, range: match.range)
                coloredRanges.append(match.range)
            }
        }

        return attributed
    }

    // MARK: - Helpers

    private static func resolveLanguage(_ raw: String) -> String {
        let lowered = raw.lowercased()
        return languageAliases[lowered] ?? lowered
    }

    private static func plainText(_ code: String) -> NSAttributedString {
        NSAttributedString(
            string: code,
            attributes: [
                .font: monoFont,
                .foregroundColor: defaultColor,
            ]
        )
    }

    private static func isOverlapping(_ range: NSRange, with existingRanges: [NSRange]) -> Bool {
        for existing in existingRanges {
            if NSIntersectionRange(range, existing).length > 0 {
                return true
            }
        }
        return false
    }
}
