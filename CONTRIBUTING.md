# Contributing to CC Settings

Thanks for your interest in contributing! This guide will help you get started.

## Prerequisites

- **macOS 26.0+** (Tahoe)
- **Xcode 16+**
- **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** — install with `brew install xcodegen`

## Setup

```bash
# Clone the repo
git clone https://github.com/Rektoooooo/CC-Settings.git
cd CC-Settings

# Generate the Xcode project
xcodegen generate

# Open in Xcode
open "CC Settings.xcodeproj"
```

Build and run with **Cmd+R**.

## Contribution Workflow

1. **Fork** the repository
2. **Create a branch** from `main` (`git checkout -b my-feature`)
3. **Make your changes** — keep commits focused and descriptive
4. **Test** — build the project and verify your changes work
5. **Push** to your fork and open a **Pull Request** against `main`

## Code Style

- **SwiftUI** — all views use SwiftUI with the `@Observable` pattern
- **Modifiers** — use existing shared modifiers like `.glassContainer()` for consistent styling
- **No external dependencies** beyond [swift-markdown](https://github.com/apple/swift-markdown) — keep the dependency footprint minimal
- **File organization** — follow the existing `Views/<Section>/` folder structure
- **Swift 6.0** — the project uses strict concurrency checking

## Reporting Issues

- Use [GitHub Issues](https://github.com/Rektoooooo/CC-Settings/issues) for bug reports and feature requests
- Include steps to reproduce for bugs
- Screenshots are helpful for UI issues

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
