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
**v1.6.0 SHIPPED.** https://github.com/Rektoooooo/CC-Settings/releases/tag/v1.6.0

- Version 1.6.0 / build 24 (`project.yml` + `Info.plist`), commit `078ccb7`, tag `v1.6.0`
- Notarization **Accepted** (submission `d724f8fe-b57b-479a-86a2-04eb718d740e`), stapled, validated
- DMG uploaded (10,277,948 bytes), URL returns HTTP 200; raw `appcast.xml` on `main` serves the
  1.6.0 / build 24 item with a matching `edSignature` and `length`
- `gh` was switched to `Rektoooooo` for the push and **switched back to `SebkuceraRSM`** afterwards

- `xcodebuild` Debug: **BUILD SUCCEEDED**
- `xcodebuild` Release (Swift 6 strict concurrency): **BUILD SUCCEEDED**
- Test target: **compiles** (`TEST BUILD SUCCEEDED`)
- Release app launched; `~/.claude/settings.json` byte-identical after load (key-preservation
  invariant holds)

## Test harness — was broken, now fixed
`xcodebuild test` used to fail before running anything:

> The test runner crashed while preparing to run tests … **More than one NSApplication
> instance was created**

Reproduced identically on unmodified `HEAD` (2ac3875) in a throwaway worktree, so it predated
this change — **the unit tests added in v1.5.1 had never actually executed.** Cause: the
`CC SettingsTests` bundle was hosted by the app, and XCTest injects into the SwiftUI `@main`
app while it is standing up its own NSApplication.

Fix (in `project.yml`): the bundle is now hostless. App sources compile straight into the test
bundle, `@testable import CC_Settings` was dropped (types are in-module), and because the test
target no longer depends on the app target the scheme has to list it explicitly:

```yaml
  CC Settings:
    scheme:
      testTargets: [CC SettingsTests, CC SettingsUITests]
```

Result: **15 unit tests + 1 UI test, all passing.** If you ever add a test that needs a real
running app, it belongs in `CC SettingsUITests` (still hosted), not here.

## What's next
1. Optional: `modelPicker` curation UI — the one reviewed key deliberately deferred. It is
   `{ options: [rows], replaceBuiltInOptions: bool }`, user-or-managed scope, needs a
   reorderable list editor.
2. Next sync baseline is **2.1.263** — the commit message carries it, which is how
   `changelog-sync` Step 1 finds it.
3. Read the key names out of the binary again (see method note above). Do not trust the docs.

## Key files touched
- `CC Settings/Models/ModelVersion.swift`
- `CC Settings/Models/ClaudeSettings.swift`
- `CC Settings/Services/ConfigurationManager.swift` (knownSettingsKeys fix)
- `CC Settings/Views/General/GeneralSettingsView.swift`
- `CC Settings/Views/Environment/EnvironmentView.swift`
- `CC Settings/Views/Hooks/HooksView.swift`
- `CC SettingsTests/CC_SettingsTests.swift`
- `CHANGELOG.md`
