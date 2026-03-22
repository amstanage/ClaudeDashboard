import AppKit

struct FileAttachment: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let fileName: String
    let fileType: FileType
    let fileSize: Int64
    let thumbnailData: Data?

    enum FileType: Equatable, Hashable, Sendable {
        case image, pdf, code, text, other
    }

    var thumbnail: NSImage? {
        thumbnailData.flatMap { NSImage(data: $0) }
    }

    static func == (lhs: FileAttachment, rhs: FileAttachment) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static let maxFileSize: Int64 = 1_000_000
    static let maxTotalSize: Int64 = 5_000_000
    static let maxFileCount = 10

    static func isWithinSizeLimit(bytes: Int64) -> Bool {
        bytes <= maxFileSize
    }

    static func fileType(for fileName: String) -> FileType {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "gif", "svg", "webp", "bmp", "tiff": return .image
        case "pdf": return .pdf
        case "swift", "py", "js", "ts", "tsx", "jsx", "go", "rs", "rb",
             "java", "kt", "c", "cpp", "h", "hpp", "m", "cs", "sh",
             "bash", "zsh", "json", "yaml", "yml", "toml", "xml",
             "html", "css", "scss", "sql", "r", "lua", "zig",
             "dockerfile", "makefile": return .code
        case "txt", "md", "markdown", "rst", "csv", "log": return .text
        default: return .other
        }
    }
}
