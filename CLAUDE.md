# CLAUDE.md — CC Settings

## Project Overview

CC Settings is a native macOS app (SwiftUI) for managing Claude Code configuration files. It reads and writes the same JSON, markdown, and JSONL files that Claude Code uses under `~/.claude/`. No external backend — everything is local file I/O.

## Build & Run

```bash
# Prerequisites: macOS 26.0+, Xcode 16+, XcodeGen
brew install xcodegen          # if not installed
xcodegen generate              # regenerate after changing project.yml
open "CC Settings.xcodeproj"   # Cmd+R to build and run
```

- **project.yml** is the source of truth for build config (XcodeGen)
- After modifying `project.yml`, always run `xcodegen generate` before building
- The Xcode project file is gitignored — never edit it directly

## Architecture

```
CC Settings/
├── App/           # Entry point, AppDelegate, ContentView (NavigationSplitView router)
├── MenuBar/       # Menu bar HUD integration
├── Models/        # Pure data structs (Codable) — no business logic
├── Services/      # Singletons managing state and file I/O
├── Views/         # SwiftUI views organized by feature section
│   ├── Common/    # Shared modifiers and reusable components
│   └── <Section>/ # One folder per sidebar section
└── Resources/     # Info.plist, entitlements, assets
```

### Services (singletons, injected via @EnvironmentObject)

| Service | Responsibility |
|---|---|
| **ConfigurationManager** | All file I/O — loads/saves settings.json, local settings, CLAUDE.md, projects, sessions, commands, MCP servers |
| **ThemeManager** | App theme state, maps to NSAppearance, persists via UserDefaults |
| **FileWatcher** | FSEvents monitoring on `~/.claude/`, debounced reload (0.5s), skips self-triggered saves |
| **StatsService** | Aggregates usage stats from JSONL sessions, caches to `~/.claude/stats-cache.json` |
| **SessionParser** | Parses `.jsonl` session files — messages, tool calls, thinking blocks, metadata |
| **GitService** | Git operations on `~/.claude/` — status, staging, commits, log, diff, push/pull |

### Managed File Paths

```
~/.claude/settings.json           # Main config (ClaudeSettings model)
~/.claude/settings.local.json     # Local overrides (LocalSettings model)
~/.claude/.env                    # API keys and env flags
~/.claude/CLAUDE.md               # Global instructions
~/.claude/commands/*.md           # Slash commands
~/.claude/skills/                 # Skills
~/.claude/plugins/                # Plugins + HUD config
~/.claude.json                    # MCP server definitions
~/.claude/projects/{encoded}/     # Per-project data (sessions, settings, CLAUDE.md)
~/.claude/stats-cache.json        # Cached analytics
```

Project paths are encoded by Claude Code: `/`, `.`, and ` ` are replaced with `-`.

## Patterns & Conventions

### State Management

- **Services**: `@MainActor class ... : ObservableObject` with `@Published` properties
- **Views**: `@State` for local state, `@EnvironmentObject` for services, `@Binding` for parent-child
- **NOT using `@Observable` macro** — the project uses traditional `ObservableObject`
- Services are injected at the app root via `.environmentObject()` on the WindowGroup

### View Structure

Every view follows this pattern:
```swift
struct SomeSettingsView: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @State private var localState: String = ""

    var body: some View {
        // Form/ScrollView/VStack as outer container
        // SettingsSection(title:description:) for grouping
        // .glassContainer() on content sections
    }

    // MARK: - Helpers
    private func helperMethod() { ... }

    @ViewBuilder
    private func subView() -> some View { ... }
}
```

### Glass Modifiers (Views/Common/GlassModifiers.swift)

The app uses a glass morphism design language. Always use these instead of raw backgrounds:

- `.glassContainer()` — standard rounded container with glass effect
- `.glassToolbar()` — for header/footer bars
- `.glassBanner(tint:)` — colored glass background

All use `RoundedRectangle(cornerRadius: 8)` with `.glassEffect()`.

### Reusable Components

- **SettingsSection** — wraps content with title + optional description, consistent spacing
- **HierarchicalModelPicker** — Claude model family/version picker with custom mode
- **MarkdownPreview** — renders markdown via swift-markdown
- **EmptyContentPlaceholder** — empty state with icon and message

### JSON Compatibility

**Critical**: ConfigurationManager preserves unknown JSON keys when saving. Claude Code may add new fields at any time — the app must never drop keys it doesn't know about. When modifying JSON encoding/decoding, always use `AdditionalPropertiesCodable` patterns or manual key preservation.

### File Saving

Every toggle, picker, and text field saves immediately — no save button. Use `configManager.saveSettings()` or the appropriate save method after any state mutation. Changes must be picked up by Claude Code on the next prompt.

### Concurrency

- All services are `@MainActor`-isolated
- Background work uses `Task { }` or `Task.detached { }`
- FileWatcher debounces to avoid rapid reload cycles
- StatsService does heavy parsing off the main actor, then updates on `@MainActor`

## Code Style

- **4 spaces** indentation (no tabs)
- **Swift 6.0** with strict concurrency checking
- **Naming**: PascalCase types, camelCase properties/functions, camelCase enum cases
- **File naming**: matches the primary type (`StatsView.swift` contains `struct StatsView`)
- **View files**: one primary view per file, private helper views/methods in the same file
- **No comments on obvious code** — only add comments where logic is non-trivial
- **Mark sections**: use `// MARK: -` for logical grouping in larger files

## Dependencies

- **swift-markdown** (0.7.3) — markdown parsing and rendering. Only external dependency.
- **Apple frameworks**: SwiftUI, AppKit, Foundation, Charts, PDFKit, CoreServices (FSEvents)
- **No external dependencies** beyond swift-markdown — keep it minimal

## Security Model

- App sandbox is **disabled** (entitlements) — required for `~/.claude/` file access
- App is not notarized — users must right-click → Open on first launch
- Never write to paths outside `~/.claude/`, `~/.claude.json`, or user-selected directories

## Release Process

Every release **must** include a DMG uploaded to GitHub Releases. Steps:

```bash
# 1. Bump version in both files
#    - project.yml: MARKETING_VERSION and CURRENT_PROJECT_VERSION
#    - CC Settings/Resources/Info.plist: CFBundleShortVersionString and CFBundleVersion

# 2. Build Release configuration
xcodebuild -project "CC Settings.xcodeproj" -scheme "CC Settings" \
  -configuration Release -derivedDataPath /tmp/cc-settings-build build

# 3. Create DMG (app + Applications symlink for drag-to-install)
DMG_DIR="/tmp/cc-settings-dmg"
rm -rf "$DMG_DIR" && mkdir -p "$DMG_DIR"
cp -R "/tmp/cc-settings-build/Build/Products/Release/CC Settings.app" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"
hdiutil create -volname "CC Settings" -srcfolder "$DMG_DIR" \
  -ov -format UDZO "CC-Settings-<version>.dmg"

# 4. Commit, push, create GitHub release with DMG
git add -A && git commit -m "Prepare v<version> release"
git push origin main
gh release create v<version> --title "v<version>" --notes "..."
gh release upload v<version> CC-Settings-<version>.dmg
```

**Important**: The DMG is for distribution only — do NOT commit it to the repo. It's listed in `.gitignore`. Always upload via `gh release upload`.

## What NOT to Do

- Don't add external dependencies without strong justification
- Don't use `@Observable` — stick with `ObservableObject` for consistency
- Don't edit the `.xcodeproj` — edit `project.yml` and run `xcodegen generate`
- Don't drop unknown JSON keys — Claude Code CLI compatibility depends on key preservation
- Don't add a save button — all changes save immediately
- Don't use raw `RoundedRectangle` backgrounds — use the glass modifiers
- Don't block the main thread — heavy work goes in `Task.detached`
