import SwiftUI

struct SessionsView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var viewModel = SessionsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search sessions...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .onSubmit { Task { await viewModel.search() } }
                if !viewModel.searchQuery.isEmpty {
                    Button { viewModel.searchQuery = ""; Task { await viewModel.loadSessions() } } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(10)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
            .padding(.horizontal, 16).padding(.top, 12)

            if !viewModel.availableModels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        FilterChip(label: "All", isSelected: viewModel.selectedModelFilter == nil) { viewModel.selectedModelFilter = nil }
                        ForEach(viewModel.availableModels, id: \.self) { model in
                            FilterChip(label: model.replacingOccurrences(of: "claude-", with: "").capitalized, isSelected: viewModel.selectedModelFilter == model) { viewModel.selectedModelFilter = model }
                        }
                    }.padding(.horizontal, 16).padding(.vertical, 8)
                }
            }

            List {
                ForEach(viewModel.filteredSessions) { session in
                    DisclosureGroup(isExpanded: Binding(
                        get: { viewModel.expandedSessionId == session.id },
                        set: { viewModel.expandedSessionId = $0 ? session.id : nil }
                    )) {
                        SessionDetailView(session: session)
                    } label: {
                        SessionRowView(session: session)
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
        .task {
            if let db = appViewModel.database { viewModel.configure(database: db) }
            await viewModel.loadSessions()
        }
    }
}

private struct SessionRowView: View {
    let session: SessionRecord
    private static let dateFormatter: DateFormatter = { let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f }()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.firstMessage ?? "Untitled session").lineLimit(1).font(.body)
                Text(Self.dateFormatter.string(from: session.startedAt)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let model = session.model {
                Text(model.replacingOccurrences(of: "claude-", with: "").capitalized)
                    .font(.caption).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(ModelUsageEntry(model: model, totalTokens: 0).color.opacity(0.2))
                    .clipShape(Capsule())
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(session.totalTokens) tokens").font(.caption)
                Text(session.durationFormatted).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

private struct FilterChip: View {
    let label: String; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(.caption).padding(.horizontal, 10).padding(.vertical, 4)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1))
        }.buttonStyle(.plain)
    }
}
