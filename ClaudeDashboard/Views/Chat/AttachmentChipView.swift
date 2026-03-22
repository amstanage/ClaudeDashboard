import SwiftUI

struct AttachmentChipView: View {
    let attachment: FileAttachment
    var onRemove: (() -> Void)? = nil
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if let thumbnail = attachment.thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(systemName: iconName)
                        .font(.caption)
                }
                Text(attachment.fileName)
                    .font(.caption)
                    .lineLimit(1)
                Text(ByteCountFormatter.string(fromByteCount: attachment.fileSize, countStyle: .file))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if let onRemove {
                    Button { onRemove() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        withAnimation(.spring(duration: 0.2)) { isExpanded.toggle() }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary)
            .clipShape(Capsule())

            if isExpanded {
                attachmentPreview
            }
        }
    }

    @ViewBuilder
    private var attachmentPreview: some View {
        let path = attachment.url.path
        switch attachment.fileType {
        case .code, .text:
            if let contents = try? String(contentsOfFile: path, encoding: .utf8) {
                let lang = attachment.fileType == .code ? (attachment.fileName as NSString).pathExtension : nil
                CodeBlockView(code: String(contents.prefix(10_000)), language: lang)
            }
        case .image:
            if let image = NSImage(contentsOfFile: path) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        case .pdf:
            PDFPreviewView(url: attachment.url)
                .frame(height: 400)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        case .other:
            Text("No preview available")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var iconName: String {
        switch attachment.fileType {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .text: return "doc.text"
        case .other: return "doc"
        }
    }
}
