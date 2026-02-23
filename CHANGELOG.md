# Changelog

All notable changes to CC Settings are documented here.

## [1.0.1] — 2026-02-23

### Fixed
- Fix Picker "opus" invalid tag warning in HierarchicalModelPicker
- Fix 22 remaining bugs from full codebase audit (#3–#28)
- Fix 5 critical bugs: data loss, pipe deadlock, resource leaks
- Match HUD preview to actual claude-hud terminal layout

### Added
- Stats dashboard with usage analytics — sessions, tokens, models, tools, daily activity charts, project rankings
- Interactive hover tooltips on Stats dashboard charts
- Copy button on session history message bubbles (always visible)

## [1.0.0] — 2026-02-20

### Added
- Initial release
- Visual settings editor for all Claude Code configuration
- Permission matrix with allow/deny/ask states and custom pattern rules
- Hook builder with event types, matchers, and shell commands
- HUD configuration with live ASCII preview and presets
- CLAUDE.md editor with source/preview/split view and templates
- Session history browser with tool use visualization and thinking blocks
- Slash commands browser and editor
- Skills browser with multi-file viewer
- Plugin marketplace browser
- MCP server configuration (stdio and SSE transports)
- File browser for global and per-project Claude Code files
- Storage cleanup dashboard with bulk delete
- Built-in git integration (status, staging, commits, diffs, push/pull)
- Global search across all settings sections
- Theme accent colors and app icon
