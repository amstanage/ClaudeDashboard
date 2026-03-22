import SwiftUI

struct MessageContentView: View {
    let content: String

    var body: some View {
        let blocks = ContentParser.parse(content)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(blocks, id: \.id) { block in
                blockView(for: block)
            }
        }
    }

    @ViewBuilder
    private func blockView(for block: MessageBlock) -> some View {
        switch block {
        case .text(let attributedString):
            Text(attributedString)
                .textSelection(.enabled)

        case .inlineCode(let code):
            Text(code)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 4))

        case .codeBlock(let language, let code):
            CodeBlockView(code: code, language: language)

        case .fileReference(let path):
            FileReferenceView(path: path)

        case .image(let url):
            if url.isFileURL, let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 400, maxHeight: 300)
                    .fixedSize()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fit).frame(maxWidth: 400, maxHeight: 300)
                } placeholder: {
                    ProgressView()
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
