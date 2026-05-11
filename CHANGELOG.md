# Changelog

All notable changes to CC Settings are documented here.

## [1.2.2] — 2026-05-11

### Added
- `skillOverrides` setting (Default / Name Only / User-Invocable Only / Off) in General → Language & Output
- `prUrlTemplate` setting in General → Attribution for custom PR-badge URLs
- `alwaysLoad` toggle on the MCP server editor — bypasses tool-search deferral for that server
- New environment variables in the Environment view:
  - Display: `CLAUDE_CODE_HIDE_CWD`, `CLAUDE_CODE_FORCE_SYNC_OUTPUT`
  - Updates section (new): `DISABLE_UPDATES`, `CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE`
  - Subagents & Gateway Discovery section (new): `CLAUDE_CODE_FORK_SUBAGENT`, `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY`
  - Bedrock section (new): `ANTHROPIC_BEDROCK_SERVICE_TIER`

### Fixed
- Removed invalid "Auto" tag from effort-level pickers — Claude Code's effort scale is `low / medium / high / xhigh / max`
- Startup freeze: subprocess execution in `runShell` no longer blocks executor threads under the `async` API surface — thanks @lemoran (#6)

## [1.2.1] — 2026-04-16

### Added
- Opus 4.7 and Opus 4.7 (1M context) in the model picker
- `Xhigh` effort level (between High and Max) to match Claude Code's new intelligence scale
- Project-level effort override now exposes the full scale (Auto/Low/Medium/High/Xhigh/Max)

### Changed
- HUD previews and model-format examples updated to Opus 4.7
- Environment placeholder examples bumped to `claude-opus-4-7`
- General effort caption is now model-agnostic ("Controls adaptive reasoning effort on Opus models")

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
