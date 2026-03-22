import SwiftUI
import PDFKit

struct FileReferenceView: View {
    let path: String
    @State private var isExpanded = false
    @State private var fileExists = false

    private var fileName: String { (path as NSString).lastPathComponent }
    private var fileExtension: String { (path as NSString).pathExtension.lowercased() }

    var body: some View {
        Group {
            if fileExists {
                VStack(alignment: .leading, spacing: 4) {
                    chipButton
                    if isExpanded {
                        expandedContent
                    }
                }
            } else {
                Text(path)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            fileExists = FileManager.default.fileExists(atPath: path)
        }
    }

    private var chipButton: some View {
        Button {
            withAnimation(.spring(duration: 0.2)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.caption)
                Text(fileName)
                    .font(.caption)
                    .lineLimit(1)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        let type = FileAttachment.fileType(for: fileName)
        switch type {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .text: return "doc.text"
        case .other: return "doc"
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        let type = FileAttachment.fileType(for: fileName)
        switch type {
        case .code, .text:
            if let contents = try? String(contentsOfFile: path, encoding: .utf8) {
                let lang = type == .code ? fileExtension : nil
                CodeBlockView(code: String(contents.prefix(10_000)), language: lang)
            } else {
                Text("Unable to read file").font(.caption).foregroundStyle(.secondary).padding(8)
            }

        case .image:
            if let image = NSImage(contentsOfFile: path) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("Unable to load image").font(.caption).foregroundStyle(.secondary).padding(8)
            }

        case .pdf:
            PDFPreviewView(url: URL(fileURLWithPath: path))
                .frame(height: 400)
                .clipShape(RoundedRectangle(cornerRadius: 8))

        case .other:
            fileMetadataView
        }
    }

    private var fileMetadataView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: path) {
                if let size = attrs[.size] as? Int64 {
                    Text("Size: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
                        .font(.caption)
                }
                if let date = attrs[.modificationDate] as? Date {
                    Text("Modified: \(date.formatted())")
                        .font(.caption)
                }
            }
            Button("Open in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundStyle(.accent)
        }
        .padding(8)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct PDFPreviewView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PDFKit.PDFView {
        let pdfView = PDFKit.PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }

    func updateNSView(_ pdfView: PDFKit.PDFView, context: Context) {}
}
