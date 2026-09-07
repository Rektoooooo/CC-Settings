# 2026-06-10 — Claude Code 2.1.155–2.1.170 catch-up

## What was done
Ran the `changelog-sync` skill. Baseline was Claude Code 2.1.154 (app v1.4.0, released 2026-05-29).
Reviewed the changelog delta 2.1.155–2.1.170 and implemented all in-scope config surfaces.
Committed as `feat: catch up on Claude Code 2.1.155–2.1.170` (not pushed, no version bump yet).

### Implemented
- **Fable 5 (2.1.170)** — new `ModelFamily.fable` case + `claude-fable-5`, `claude-fable-5[1m]`,
  `fable` alias in `Models/ModelVersion.swift`. Propagates automatically to
  `HierarchicalModelPicker` and `MenuBarController` (both iterate `allCases`).
- **fallbackModel (2.1.166)** — `[String]?` on `ClaudeSettings` with tolerant decode
  (accepts legacy single string, normalizes to array). Comma-separated TextField in
  General → Model, capped at 3 entries on save (CLI ignores extras).
- **disableBundledSkills (2.1.169)** — inverted-polarity "Bundled Skills" toggle in
  General → Language & Output, plus `CLAUDE_CODE_DISABLE_BUNDLED_SKILLS` flag in a new
  Skills section in Environment.
- **workflowKeywordTriggerEnabled (2.1.157)** — "Ultracode Keyword Trigger" toggle next
  to Dynamic Workflows. Default true; writes `false` only when off, clears key when on.
- **ANTHROPIC_DEFAULT_FABLE_MODEL** — fable alias pin row in Environment → Model Overrides
  (also needed for Fable safeguard fallback on Bedrock/Vertex/Foundry).

### Out of scope (reviewed, intentionally not implemented)
- `requiredMinimumVersion`/`requiredMaximumVersion` — managed-settings.json, app doesn't manage it
- Stop/SubagentStop `hookSpecificOutput.additionalContext` — hook *output*, not config
- Skill `$` escape syntax, post-session runner hook, `--safe-mode`, `/cd`, `/plugin list` — CLI/authoring
- `CLAUDE_CODE_OPUS_4_6_FAST_MODE_OVERRIDE` removal — app never listed it
- `agent` settings.json field (2.1.157 "now honored") — pre-existing key, round-trips via key preservation

### Follow-up (same day): model picker cleanup
User reported the picker still showed only Opus/Sonnet/Haiku — they were running the
pre-commit binary. Verified the picker DOES write the `model` key to settings.json
(GeneralSettingsView.swift ~line 716). Added `isLegacy` to `ModelVersion`: Opus 4.7/4.6,
Sonnet 4.5, Haiku 3.5 stay in the catalog (so old configs resolve display names) but are
hidden from the picker + menu bar via `versions(for:)`. Rebuilt and relaunched the app.

### Follow-up: v1.5.0 RELEASED
Full release flow completed same day:
- HUD preview strings Opus 4.8 → Fable 5; version bumped to 1.5.0 (build 22) in project.yml + Info.plist
- Release build (Swift 6 strict concurrency OK), Sparkle re-signed inside-out, codesign verified
- DMG notarized (Accepted, id 1cc5be45-b6d6-4d68-926a-55b1b878cf0d), stapled, Sparkle-signed
- appcast.xml updated, pushed; release: https://github.com/Rektoooooo/CC-Settings/releases/tag/v1.5.0
- Gotcha: push initially 403'd — gh was on the SebkuceraRSM account; fixed with `gh auth switch -u Rektoooooo`
- Gotcha: CLAUDE.md says .xcodeproj is gitignored — it's actually TRACKED (past release commits include it); included in the release commit
- Verified: DMG URL returns 200, raw appcast on main serves the 1.5.0 item

## Status
**v1.5.0 shipped.** All commits pushed to `main`, tag v1.5.0 published with DMG asset.

## Gotchas hit
- Adding the `fallbackModels` onChange to the existing `Color.clear` observer chain in
  `GeneralSettingsView.autoSaveObservers` blew SwiftUI's type-check limit — it needed its
  own `Color.clear` block AND the parsing extracted to `saveFallbackModels()`.

## What's next
- Push + decide whether this becomes v1.5.0 (release process in CLAUDE.md: bump project.yml
  + Info.plist, Release build, notarize, appcast).
- Optional cosmetic: HUDView preview strings still say "Opus 4.8" (`Views/HUD/HUDView.swift`
  lines ~272, 540-542, 1443-1445) — example text only, but could read "Fable 5" now.
- Rebuild in **Release** before tagging (strict concurrency diagnostics).

## Key files touched
- `CC Settings/Models/ModelVersion.swift`
- `CC Settings/Models/ClaudeSettings.swift`
- `CC Settings/Views/General/GeneralSettingsView.swift`
- `CC Settings/Views/Environment/EnvironmentView.swift`
