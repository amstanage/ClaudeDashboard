import SwiftUI

struct SkillInfo: Identifiable {
    let id: String
    let name: String
    let description: String
    let source: SkillSource
    let path: String

    enum SkillSource: String {
        case user = "User"
        case plugin = "Plugin"
    }
}

@MainActor @Observable
final class SkillsViewModel {
    var skills: [SkillInfo] = []

    func loadSkills() {
        var found: [SkillInfo] = []
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        // User skills: ~/.claude/skills/*/SKILL.md
        let userSkillsDir = home.appendingPathComponent(".claude/skills")
        if let dirs = try? fm.contentsOfDirectory(at: userSkillsDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            for dir in dirs {
                let skillFile = dir.appendingPathComponent("SKILL.md")
                if let info = parseSkillFile(at: skillFile, source: .user) {
                    found.append(info)
                }
            }
        }

        // Plugin skills: ~/.claude/plugins/cache/*/*/skills/*/SKILL.md
        let pluginCacheDir = home.appendingPathComponent(".claude/plugins/cache")
        if let orgs = try? fm.contentsOfDirectory(at: pluginCacheDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            for org in orgs {
                if let plugins = try? fm.contentsOfDirectory(at: org, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                    for plugin in plugins {
                        // Find versioned directories
                        if let versions = try? fm.contentsOfDirectory(at: plugin, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                            for version in versions {
                                let skillsDir = version.appendingPathComponent("skills")
                                if let skillDirs = try? fm.contentsOfDirectory(at: skillsDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                                    for skillDir in skillDirs {
                                        let skillFile = skillDir.appendingPathComponent("SKILL.md")
                                        if let info = parseSkillFile(at: skillFile, source: .plugin) {
                                            found.append(info)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Deduplicate by name (keep first occurrence)
        var seen = Set<String>()
        skills = found.filter { seen.insert($0.name).inserted }
    }

    private func parseSkillFile(at url: URL, source: SkillInfo.SkillSource) -> SkillInfo? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        // Parse YAML frontmatter
        guard content.hasPrefix("---") else { return nil }
        let parts = content.components(separatedBy: "---")
        guard parts.count >= 3 else { return nil }

        let frontmatter = parts[1]
        var name = url.deletingLastPathComponent().lastPathComponent
        var description = ""

        for line in frontmatter.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("name:") {
                name = trimmed.replacingOccurrences(of: "name:", with: "").trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
            } else if trimmed.hasPrefix("description:") {
                description = trimmed.replacingOccurrences(of: "description:", with: "").trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
            }
        }

        return SkillInfo(id: "\(source.rawValue)-\(name)", name: name, description: description, source: source, path: url.path)
    }
}

struct SkillsView: View {
    @State private var viewModel = SkillsViewModel()
    @State private var searchText = ""

    private var filteredSkills: [SkillInfo] {
        if searchText.isEmpty { return viewModel.skills }
        return viewModel.skills.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var userSkills: [SkillInfo] {
        filteredSkills.filter { $0.source == .user }
    }

    private var pluginSkills: [SkillInfo] {
        filteredSkills.filter { $0.source == .plugin }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search skills...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(10)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
            .padding(.horizontal, 16).padding(.top, 12)

            // Skills count
            HStack {
                Text("\(viewModel.skills.count) skills installed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 8)

            // Skills list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if !userSkills.isEmpty {
                        SkillSectionView(title: "User Skills", icon: "person", skills: userSkills)
                    }
                    if !pluginSkills.isEmpty {
                        SkillSectionView(title: "Plugin Skills", icon: "puzzlepiece.extension", skills: pluginSkills)
                    }
                    if filteredSkills.isEmpty {
                        Text("No skills found")
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    }
                }
                .padding(16)
            }
        }
        .onAppear { viewModel.loadSkills() }
    }
}

private struct SkillSectionView: View {
    let title: String
    let icon: String
    let skills: [SkillInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            ForEach(skills) { skill in
                SkillRowView(skill: skill)
            }
        }
    }
}

private struct SkillRowView: View {
    let skill: SkillInfo
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(skill.name)
                    .font(.body)
                    .fontWeight(.medium)
                Spacer()
                Text("/\(skill.name)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fontDesign(.monospaced)
            }
            if !skill.description.isEmpty {
                Text(skill.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
