# Changelog

All notable changes to CC Settings are documented here.

## [1.5.1] — 2026-07-26

Catch-up baseline: Claude Code **2.1.171 – 2.1.220**. Key names, types, enum values and
defaults in this release were verified against the settings schemas inside the shipped
2.1.220 binary rather than the published docs, which are out of date in places.

### Added
- **Claude Opus 5** and **Opus 5 (1M context)** — Opus 5 is now Claude Code's default Opus model
- **Claude Sonnet 5** — natively 1M-context
- `workflowSizeGuideline` — Dynamic Workflow Size picker (Unrestricted / Small / Medium / Large)
- New **Terminal & Accessibility** section: `axScreenReader`, `showMessageTimestamps`,
  `terminalProgressBarEnabled`, `syntaxHighlightingDisabled`, `autoScrollEnabled`,
  `wheelScrollAccelerationEnabled`, `hideVimModeIndicator`, `vimInsertModeRemaps`
- New **Agent View & Remote Control** section: `disableAgentView`, `subagentStatusLine`,
  `disableRemoteControl`, `remoteControlAtStartup`, `agentPushNotifEnabled`
- Behavior: `askUserQuestionTimeout`, `fileCheckpointingEnabled`, `todoFeatureEnabled`,
  `awaySummaryEnabled`, `promptSuggestionEnabled`, `emojiCompletionEnabled`,
  `fileSuggestion`, `autoCompactWindow`, `precomputeCompactionEnabled`
- Model: `advisorModel`, `enforceAvailableModels`
- Enterprise: `allowedMcpServers`, `strictKnownMarketplaces`, `blockedMarketplaces`,
  `channelsEnabled`, `disableClaudeAiConnectors`, `disableSideloadFlags`,
  `disableSkillShellExecution`, `disableDeepLinkRegistration`, `feedbackSurveyRate`,
  `enableArtifact` / `disableArtifact`
- Attribution: `attribution.sessionUrl` — omit the claude.ai session link from commits and PRs
- Sandbox: `sandbox.credentials` (files / envVars / allowPlaintextInject),
  `sandbox.filesystem.disabled`, `sandbox.allowAppleEvents`,
  `sandbox.network.strictAllowlist`, `deniedDomains`, `allowManagedDomainsOnly`
- Auto Mode: `autoMode.classifyAllShell`
- Seven hook events: `DirectoryAdded`, `PostToolBatch`, `StopFailure`,
  `UserPromptExpansion`, `TaskCreated`, `CwdChanged`, `FileChanged`
- `iterm2` teammate display mode
- Environment: `CLAUDE_AX_SCREEN_READER`, `CLAUDE_CODE_DISABLE_MOUSE_CLICKS`,
  `CLAUDE_CODE_PROCESS_WRAPPER`, `CLAUDE_CLIENT_PRESENCE_FILE`,
  `CLAUDE_CODE_RETRY_WATCHDOG`, `CLAUDE_CODE_OTEL_CONTENT_MAX_LENGTH`,
  `CLAUDE_CODE_DISABLE_AGENT_VIEW`, `CLAUDE_CODE_DISABLE_ARTIFACT`,
  `CLAUDE_CODE_DISABLE_FILE_CHECKPOINTING`, `CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY`,
  `CLAUDE_CODE_DISABLE_AUTO_MEMORY`, `CLAUDE_CODE_SKIP_PROMPT_HISTORY`,
  `CLAUDE_CODE_USE_POWERSHELL_TOOL`, `DISABLE_DOCTOR_COMMAND`
- Unit tests covering the new keys, hook events and model-catalog invariants

### Changed
- Opus 4.8 and Sonnet 4.6 are now hidden from the picker, keeping one current variant per
  family. Existing configs pinned to them still resolve to readable names.

### Fixed
- **`claude-fable-5[1m]` was not a real model ID.** Fable 5 is natively 1M-context but has no
  `[1m]` suffix variant, so the entry added in 1.5.0 wrote a model string Claude Code doesn't
  recognise as distinct. Removed from the picker; existing configs still display as "Fable 5".
- Duplicate `UserPromptSubmit` / `PermissionDenied` cases in the hooks scope-collection switch
- Editing hooks no longer clears the `hooks` object while one of the seven new events is set

## [1.5.0] — 2026-06-10

Catch-up baseline: Claude Code 2.1.155–2.1.170.

### Added
- **Claude Fable 5** — fourth model family in the picker (Fable 5, Fable 5 with 1M context,
  `fable` alias), in both the app and the menu bar switcher
- **Fallback Models** — up to three models tried in order when the primary is overloaded
  (`fallbackModel`, Claude Code 2.1.166)
- **Bundled Skills toggle** — hide Claude Code's built-in skills from the model
  (`disableBundledSkills` + `CLAUDE_CODE_DISABLE_BUNDLED_SKILLS`, 2.1.169)
- **Ultracode Keyword Trigger toggle** (`workflowKeywordTriggerEnabled`, 2.1.157)
- Environment: `ANTHROPIC_DEFAULT_FABLE_MODEL` alias pin

### Changed
- Cleaner model picker — only current variants are shown; legacy versions (Opus 4.7/4.6,
  Sonnet 4.5, Haiku 3.5) are hidden but still resolve to readable names in existing configs
- HUD previews refreshed to Fable 5

## [1.4.0] — 2026-05-29

### Added
- **Ultracode** effort option and a **Dynamic Workflows** toggle (`disableWorkflows`)
- **HTTP/SSE MCP tool discovery** now authenticates with the stored OAuth token — auto-approval
  lists finally populate for servers like GitHub and NetSuite (was HTTP 401)
- **Project-local MCP servers** stored inline in `~/.claude.json`
  (`projects[path].mcpServers`) are now shown and editable, saved back to the correct file
- **Live reload** across many sections (MCP, sessions, stats, git, themes, profiles, storage
  badges, commands/skills/plugins) when files change on disk

### Fixed
- Model picker no longer shows a fabricated "Sonnet" when no model is set — shows "Default"
  instead, and never persists a model you didn't pick
- Session threads no longer drop your messages (`MessageRole.user` was `"human"`; JSONL uses `"user"`)
- Saving sandbox / hooks / MCP / permissions no longer drops config keys — including
  per-server `oauth` tokens
- Plugins badge counts **installed** plugins, not the whole catalog
- Stats headline relabeled "I/O Tokens"; git detached-HEAD and renamed-file handling fixed;
  backups folder now lists its files

## [1.3.0] — 2026-05-28

### Added
- **MCP per-action auto-approval** — the MCP Servers tab discovers a server's actions live via
  the MCP `tools/list` handshake, then lets you toggle auto-accept per action, or flip
  "Auto-accept all" for the whole server. Writes matching `mcp__server__tool` / `mcp__server`
  rules into `permissions.allow`. Falls back to previously-used plus manual entry when a
  server is offline.
- **Claude Opus 4.8** (and 1M-context variant) in the model picker
- New `MessageDisplay` hook event, `worktree.bgIsolation` setting, `disallowed-tools` for
  commands, and enterprise settings (`allowAllClaudeAiMcps`, `pluginSuggestionMarketplaces`)

### Changed
- HUD previews and model-override placeholders refreshed to Opus 4.8

### Removed
- Deprecated Opus 4.0 / Sonnet 4.0 entries (retired 15 June); fixed the Sonnet 4.5 snapshot ID

### Fixed
- Scrolled content bleeding into the window titlebar on the MCP server detail pane

## [1.2.3] — 2026-05-14

### Changed
- **Accurate built-in theme palettes** — the six built-in Claude Code theme previews use colors
  resampled pixel-for-pixel from the CLI's own rendering, so previews match what you see
- **Adaptive preview surfaces** — light themes render on a white background, dark themes on dark
- Scaffolding a new theme from a preset adopts a light or dark surface based on app appearance
- Sidebar Themes badge counts built-in themes plus custom files, and updates correctly on load

### Removed
- Redundant "0 custom" footer label

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
