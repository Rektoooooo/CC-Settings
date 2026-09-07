# 2026-09-07 — Claude Code 2.1.221–2.1.263 catch-up (Fable 5.1)

## What was done
Pulled `main` (fast-forward to `2ac3875`, v1.5.1 — that release happened after the last
handoff was written, so the 2026-06-10 handoff was stale). Ran the `changelog-sync` skill
against the new baseline.

- Baseline: Claude Code **2.1.220** (app v1.5.1). Installed CLI: **2.1.263**.
- Delta reviewed: 2.1.221 → 2.1.263, every entry.

### Method note — the docs are not usable for this
The published settings docs were missing **16 of the 19** keys reviewed. Ground truth came
from the zod settings schemas embedded in the shipped binary at
`~/.local/share/claude/versions/2.1.263`:

```bash
strings -a ~/.local/share/claude/versions/2.1.263 > /tmp/cc-strings.txt
# then grep for `<key>:` and read the .describe("...") text and enum arrays
```

The `/model` picker catalog (display names, descriptions, `[1m]` rows, aliases like
`fable51`) sits around byte offset ~74.86M — `dd bs=1 skip=74860000 count=14000 | strings`.
Use this technique again next time; it is the only reliable source.

### Implemented
- **Fable 5.1** `claude-fable-5-1` added as the current Fable; Fable 5 marked `isLegacy`.
  Confirmed **no** `claude-fable-5-1[1m]` exists — Fable has no 1M row at all.
- **`claude-sonnet-5[1m]` added** — v1.5.1 wrongly assumed Sonnet 5 had no `[1m]` variant.
  The binary has the ID plus "Sonnet 5 (1M context)" picker strings, exactly like the Opus
  1M rows. The test that encoded the wrong assumption was corrected, with the evidence in
  its doc comment.
- New settings.json keys, all with binary-verified types/enums: `timeFormat`, `timeZone`,
  `promptCacheTtl`, `bashOutputMaxChars`, `taskOutputMaxChars`, `autoContinueAtUsageLimit`,
  `crossSessionInbound`, `dialogExpiry`, `spellcheck` (an **object**, not a bool).
- Hooks `PreModelSwitch` / `PostModelSwitch` — model, HooksView (all 6 switches) and **both
  emptiness checks** (missing those is the bug 1.5.1 had to fix for the previous 7 events).
- 9 new env vars in EnvironmentView.
- **Bug fix:** `knownSettingsKeys` in ConfigurationManager was missing all 42 fields added
  in 1.5.0/1.5.1. Latent (everything currently saves via `saveField`, which removes keys
  directly) but it would bite the first time anyone nils a field and calls `saveSettings()`.
  Now verified equal to the model's property list by script.

### Not adopted (deliberate)
`keybindingFlavor` (deprecated, no effect as of 2.1.263) · `managedMcpServers`,
`modelPricing`, `allowedMarketplaces` (managed-settings.json only) · Mythos 5/5.1 (no picker
alias; approved orgs only) · `modelPicker` (real, user-scoped, but a curation array of
labelled rows — **the one genuine follow-up**).

## Status
Code complete on `main`, **not committed, not released**. Version still 1.5.1 / build 23.

- `xcodebuild` Debug: **BUILD SUCCEEDED**
- `xcodebuild` Release (Swift 6 strict concurrency): **BUILD SUCCEEDED**
- Test target: **compiles** (`TEST BUILD SUCCEEDED`)
- Release app launched; `~/.claude/settings.json` byte-identical after load (key-preservation
  invariant holds)

## Blocker — pre-existing, NOT caused by this work
`xcodebuild test` cannot run the unit bundle:

> The test runner crashed while preparing to run tests … **More than one NSApplication
> instance was created**

Reproduced identically on unmodified `HEAD` (2ac3875) in a throwaway worktree, so it predates
this change — **the unit tests added in v1.5.1 have never actually executed.** Cause: the
`CC SettingsTests` bundle is hosted by the app, and the SwiftUI `@main` +
`@NSApplicationDelegateAdaptor` entry point collides with the runner's NSApplication.
Fix is a `project.yml` test-target change (drop the test host so the model/decode tests run
as a logic bundle) — deliberately left alone here as it is app-startup surgery unrelated to a
changelog sync. **Decide on this before the next release.**

## What's next
1. Decide the test-host fix above.
2. Decide whether this becomes v1.6.0 → bump `project.yml` + `Info.plist`, then the full
   release flow in CLAUDE.md (Release build → re-sign Sparkle inside-out → DMG → notarize →
   staple → sign_update → appcast → tag → `gh release upload`).
3. `gh auth switch -u Rektoooooo` before any push/release — the other account 403s.
4. Optional: `modelPicker` curation UI.

## Key files touched
- `CC Settings/Models/ModelVersion.swift`
- `CC Settings/Models/ClaudeSettings.swift`
- `CC Settings/Services/ConfigurationManager.swift` (knownSettingsKeys fix)
- `CC Settings/Views/General/GeneralSettingsView.swift`
- `CC Settings/Views/Environment/EnvironmentView.swift`
- `CC Settings/Views/Hooks/HooksView.swift`
- `CC SettingsTests/CC_SettingsTests.swift`
- `CHANGELOG.md`
