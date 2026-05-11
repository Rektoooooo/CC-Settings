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

Every release **must** include a signed, notarized DMG uploaded to GitHub Releases, plus an updated `appcast.xml` for Sparkle auto-updates.

### Signing & Notarization Credentials

- **Code signing identity**: `Developer ID Application: IC Servis, s.r.o. (PH3V9JYRDW)`
- **Team ID**: `PH3V9JYRDW`
- **Apple ID**: `sebastian.kucera@icloud.com`
- **Notarytool credentials**: stored in Keychain under profile `CC-Settings-Notarize`. To (re)create: `xcrun notarytool store-credentials "CC-Settings-Notarize" --apple-id "sebastian.kucera@icloud.com" --team-id "PH3V9JYRDW" --password "<app-specific-password>"`. Generate the app-specific password at [account.apple.com](https://account.apple.com) → Sign-In and Security → App-Specific Passwords.
- **Sparkle EdDSA key**: stored in Keychain (account `ed25519`). The matching public key embedded in the app is `EXlWEgu6DpdzLNS+Qt6Yr5XZnP/IotgJun7O6tUJIkg=`. Verify with `generate_keys -p`. If lost, the only way to keep auto-update working is to recover it from another machine that has the same Keychain item — generating a new keypair breaks auto-update for all existing installs.
- **Sparkle tools**: live inside the Release-build SPM artifact at `/tmp/cc-settings-build/SourcePackages/artifacts/sparkle/Sparkle/bin/` (`sign_update`, `generate_keys`). Do NOT use `/tmp/sparkle/` — it's volatile and gone after reboot.

### Setup on a new machine (one-time)

If `security find-identity -v -p codesigning` shows 0 valid identities:

1. **Developer ID cert**: either import an existing `.p12` backup, or issue a new one. To issue new — generate a CSR (`openssl req -new -newkey rsa:2048 -nodes -keyout key.pem -out csr.csr -subj "/emailAddress=.../CN=.../C=CZ"`), upload at [developer.apple.com](https://developer.apple.com/account/resources/certificates/add) → Developer ID Application → G2 profile, download `.cer`, then bundle into `.p12` and import: `openssl x509 -in cert.cer -inform DER -out cert.pem && openssl pkcs12 -export -legacy -in cert.pem -inkey key.pem -out cert.p12 -passout pass:temp && security import cert.p12 -k ~/Library/Keychains/login.keychain-db -P temp -T /usr/bin/codesign`.
2. **Apple intermediate**: a newly-issued G2 cert needs Apple's intermediate to validate. Install once: `curl -fsSL https://www.apple.com/certificateauthority/DeveloperIDG2CA.cer -o /tmp/g2.cer && security import /tmp/g2.cer -k ~/Library/Keychains/login.keychain-db`.
3. **Sparkle key**: do NOT run `generate_keys` without `-f` — that creates a brand new keypair and breaks auto-update for existing users. Instead, export from the other machine with `generate_keys -x ~/Desktop/sparkle-private-key.txt` and import here with `generate_keys -f ~/Desktop/sparkle-private-key.txt`.

### Release steps

```bash
# 1. Bump version in BOTH files
#    - project.yml: MARKETING_VERSION and CURRENT_PROJECT_VERSION
#    - CC Settings/Resources/Info.plist: CFBundleShortVersionString and CFBundleVersion
#    Then regenerate:
xcodegen generate

# 2. Build Release with Developer ID signing + hardened runtime
rm -rf /tmp/cc-settings-build
xcodebuild -project "CC Settings.xcodeproj" -scheme "CC Settings" \
  -configuration Release -derivedDataPath /tmp/cc-settings-build \
  CODE_SIGN_IDENTITY="Developer ID Application: IC Servis, s.r.o. (PH3V9JYRDW)" \
  DEVELOPMENT_TEAM=PH3V9JYRDW \
  CODE_SIGNING_REQUIRED=YES \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  OTHER_CODE_SIGN_FLAGS="--options runtime --timestamp" \
  build

# 3. Re-sign Sparkle's nested executables with Developer ID + timestamp.
#    Xcode only signs the outer .app — Sparkle's Autoupdate, Updater.app, and
#    XPCServices ship adhoc-signed, which notarization REJECTS. Skip this step
#    and Apple returns "The binary is not signed with a valid Developer ID
#    certificate" for every Sparkle-internal binary.
APP="/tmp/cc-settings-build/Build/Products/Release/CC Settings.app"
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
IDENTITY="Developer ID Application: IC Servis, s.r.o. (PH3V9JYRDW)"
sign() { codesign --force --options runtime --timestamp --sign "$IDENTITY" "$1"; }
# Inside-out — bundles must be re-signed after their contents:
sign "$SPARKLE/Versions/B/XPCServices/Downloader.xpc/Contents/MacOS/Downloader"
sign "$SPARKLE/Versions/B/XPCServices/Downloader.xpc"
sign "$SPARKLE/Versions/B/XPCServices/Installer.xpc/Contents/MacOS/Installer"
sign "$SPARKLE/Versions/B/XPCServices/Installer.xpc"
sign "$SPARKLE/Versions/B/Autoupdate"
sign "$SPARKLE/Versions/B/Updater.app/Contents/MacOS/Updater"
sign "$SPARKLE/Versions/B/Updater.app"
sign "$SPARKLE"
sign "$APP"
codesign --verify --deep --strict "$APP"   # must say "valid on disk"

# 4. Create styled DMG (requires: brew install create-dmg)
#    NOTE: --background flag omitted because /tmp/dmg-background.png is volatile.
#    If you have the background asset somewhere persistent, add it back here.
rm -f /tmp/CC-Settings-<version>.dmg
create-dmg \
  --volname "CC Settings" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 80 \
  --icon "CC Settings.app" 175 175 \
  --app-drop-link 485 175 \
  --hide-extension "CC Settings.app" \
  --no-internet-enable \
  "/tmp/CC-Settings-<version>.dmg" \
  "/tmp/cc-settings-build/Build/Products/Release/CC Settings.app"

# 5. Notarize with Apple (uses stored keychain profile — no password in CLI)
xcrun notarytool submit /tmp/CC-Settings-<version>.dmg \
  --keychain-profile "CC-Settings-Notarize" \
  --wait
# If "Invalid", inspect the log to see exactly which binary tripped it:
#   xcrun notarytool log <submission-id> --keychain-profile "CC-Settings-Notarize"

# 6. Staple the notarization ticket to the DMG
xcrun stapler staple /tmp/CC-Settings-<version>.dmg
xcrun stapler validate /tmp/CC-Settings-<version>.dmg

# 7. Sign DMG for Sparkle auto-updates
/tmp/cc-settings-build/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update \
  /tmp/CC-Settings-<version>.dmg
# Outputs: sparkle:edSignature="..." length="..."

# 8. Update appcast.xml — prepend a new <item> at the top of <channel>:
#    - sparkle:version (CURRENT_PROJECT_VERSION)
#    - sparkle:shortVersionString (MARKETING_VERSION)
#    - <pubDate>Mon, 11 May 2026 08:00:00 +0000</pubDate> (RFC-2822 format)
#    - enclosure url: https://github.com/Rektoooooo/CC-Settings/releases/download/v<version>/CC-Settings-<version>.dmg
#    - sparkle:edSignature and length from step 7

# 9. Commit, push, tag, create GitHub release, upload DMG
git add -A && git commit -m "Prepare v<version> release"
git push origin main
git tag -a v<version> -m "v<version> — <one-line summary>"
git push origin v<version>
gh release create v<version> --title "v<version>" --notes "..."
gh release upload v<version> /tmp/CC-Settings-<version>.dmg
```

**Important**: The DMG is for distribution only — do NOT commit it to the repo. It's listed in `.gitignore`. Always upload via `gh release upload`.

### Common notarization failures

| Failure | Cause | Fix |
|---|---|---|
| `not signed with a valid Developer ID certificate` on Sparkle binaries | Skipped step 3 (Sparkle re-sign) | Re-sign Sparkle inside-out, rebuild DMG |
| `signature does not include a secure timestamp` | Codesign ran without `--timestamp` | Add `--timestamp` to OTHER_CODE_SIGN_FLAGS and to each manual `codesign` call |
| `Apple ID and password are not matching` from notarytool | App-specific password expired/rotated | Re-run `notarytool store-credentials` with a fresh password |
| `submission status: Invalid` with no useful issues | Server-side hiccup | Wait 5 min, re-submit. If consistent, run `notarytool log <id>` |

### Contributor PR notes

- The Release config uses **Swift 6 strict concurrency**. Captures of `var` across concurrent closures (`readabilityHandler`, `terminationHandler`, `Task.detached`, etc.) will fail to compile in Release even when they pass in Debug. Wrap shared mutable state in a `final class State: @unchecked Sendable { let lock = NSLock(); var ... }` and capture the class by reference.
- Always rebuild **in Release** before tagging a version — Debug skips some concurrency diagnostics.

## What NOT to Do

- Don't add external dependencies without strong justification
- Don't use `@Observable` — stick with `ObservableObject` for consistency
- Don't edit the `.xcodeproj` — edit `project.yml` and run `xcodegen generate`
- Don't drop unknown JSON keys — Claude Code CLI compatibility depends on key preservation
- Don't add a save button — all changes save immediately
- Don't use raw `RoundedRectangle` backgrounds — use the glass modifiers
- Don't block the main thread — heavy work goes in `Task.detached`
