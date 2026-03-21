# Claude Dashboard

A native macOS app for interacting with Claude Code, featuring a chat interface, usage analytics dashboard, and session management — all styled with Apple's Liquid Glass design language.

## Features

- **Chat Interface** — Send messages to Claude via the CLI with rich message bubbles, model/effort selection, and a toggleable terminal drawer for raw output
- **Usage Dashboard** — GitHub-style heatmap showing daily token usage over the past year, weekly bar charts, monthly trend lines, and model usage breakdown
- **Session History** — Browse, search, and filter past conversations with full conversation replay
- **Skills Browser** — View installed Claude Code skills (user and plugin)
- **Live Stats Bar** — Real-time display of model, effort, sent/received tokens, message count, daily usage, and session duration
- **Keyboard Shortcuts** — Cmd+1-4 for navigation, Cmd+N for new chat, Cmd+K to clear, Cmd+T for terminal

## Requirements

- macOS 26+ (Tahoe)
- Xcode 26+
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed

## Building

```bash
git clone <repo-url>
cd ClaudeDashboard
open ClaudeDashboard.xcodeproj
```

Press **Cmd+R** to build and run.

## Architecture

- **SwiftUI** with Liquid Glass effects (`.glassEffect()`)
- **Swift Charts** for dashboard visualizations
- **SQLite3** (C API) for caching usage data
- **Foundation Process** for spawning `claude --print` CLI processes
- **FSEvents** for watching `~/.claude/projects/` for new session data

### Project Structure

```
ClaudeDashboard/
├── App/                    # App entry point, ContentView, navigation
├── Models/                 # CLIEvent, ChatMessage, SessionRecord, DailyStats
├── Services/               # CLIService, CLIEventParser, DatabaseService,
│                             JSONLReader, UsageSyncService
├── ViewModels/             # AppViewModel, ChatViewModel, DashboardViewModel,
│                             SessionsViewModel
└── Views/
    ├── Chat/               # ChatView, MessageBubbleView, MessageInputView
    ├── Components/         # GlassCard
    ├── Dashboard/          # Heatmap, WeeklyChart, MonthlyTrend, ModelUsage
    ├── Sessions/           # SessionsView, SessionDetailView
    ├── Skills/             # SkillsView
    ├── StatsBar/           # StatsBarView
    └── Terminal/           # TerminalDrawerView
```

## License

MIT
