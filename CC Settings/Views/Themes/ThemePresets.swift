import Foundation

// MARK: - Built-in themes

/// A theme that ships with Claude Code's CLI binary. Read-only in CC Settings —
/// you can activate it (writes the id to `settings.json:theme`) or duplicate
/// it as an editable starting point, but the underlying colors are baked into
/// the CLI, not stored as files.
///
/// Names + ids mirror Claude Code's `/theme` picker. The "auto" id is a sentinel
/// for "no theme set" — selecting it clears `settings.json:theme` entirely so
/// Claude Code falls back to terminal defaults.
struct BuiltInTheme: Identifiable, Hashable {
    let id: String          // value written to `settings.json:theme` ("" for auto)
    let displayName: String
    let icon: String
    let description: String
    /// Best-effort approximation of the built-in's palette. The CLI doesn't
    /// expose its actual colors, so this is what we ship for the preview.
    /// Marked as "Approximate" in the UI. Auto's palette is all-nil so the
    /// preview falls back to system colors (matching "adapts to terminal").
    let approximateColors: ThemeColors

    /// Sentinel id for the Auto / no-theme option.
    static let autoID = "auto"
    var isAuto: Bool { id == BuiltInTheme.autoID }

    static func == (lhs: BuiltInTheme, rhs: BuiltInTheme) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum ThemePresets {
    /// Themes hard-coded into Claude Code. Mirrors `/theme` in the CLI exactly.
    /// "Auto" is a synthetic entry that maps to absence of the `theme` setting.
    static let builtIns: [BuiltInTheme] = [
        BuiltInTheme(
            id: BuiltInTheme.autoID,
            displayName: "Auto (match terminal)",
            icon: "circle.lefthalf.filled",
            description: "Adapts to your terminal's appearance. No fixed colors — Claude Code uses defaults that look good in whatever terminal you're using.",
            approximateColors: ThemeColors()    // all-nil → preview uses system colors
        ),
        BuiltInTheme(
            id: "dark",
            displayName: "Dark mode",
            icon: "moon.fill",
            description: "Claude Code's default dark theme — VS Code-style syntax highlighting with red/green diff stripes.",
            approximateColors: ThemeColors(
                background: "#1e1e1e",
                foreground: "#f8f8f2",
                cursor: "#ffffff",
                selection: "#3a3a3a",
                accent: "#e53f73",
                error: "#cc625e",   // diff `-` marker / line number
                warning: "#d29922",
                success: "#72c560", // diff `+` marker / line number
                muted: "#858585",
                keyword: "#84d6ec", // let / var / func / struct — cyan
                string: "#e4db82",  // string literals — pale yellow
                comment: "#747160",
                number: "#b586f8",  // numbers — purple
                function: "#b3e053", // function names — lime green
                type: "#b3e053"     // types (String, Int) — lime green
            )
        ),
        BuiltInTheme(
            id: "light",
            displayName: "Light mode",
            icon: "sun.max.fill",
            description: "Claude Code's default light theme — GitHub-style syntax highlighting with red/green diff stripes.",
            approximateColors: ThemeColors(
                background: "#ffffff",
                foreground: "#333333",
                cursor: "#000000",
                selection: "#add6ff",
                accent: "#992c5c",
                error: "#be3536",   // diff `-` marker / line number
                warning: "#bf8700",
                success: "#458846", // diff `+` marker / line number
                muted: "#969896",
                keyword: "#992c5c", // let / var / func / struct — magenta
                string: "#1f358c",  // string literals — navy
                comment: "#969896",
                number: "#3a84af",  // numbers — blue
                function: "#755e9f", // function names — purple
                type: "#3a84af"     // types (String, Int) — blue
            )
        ),
        BuiltInTheme(
            id: "dark-daltonized",
            displayName: "Dark mode (colorblind-friendly)",
            icon: "moon.stars.fill",
            description: "Dark theme but diff `+` lines are blue instead of green — keeps add/remove distinguishable for red-green color vision.",
            approximateColors: ThemeColors(
                background: "#1e1e1e",
                foreground: "#f8f8f2",
                cursor: "#ffffff",
                selection: "#264f78",
                accent: "#e53f73",
                error: "#cc625e",   // diff `-` stays reddish
                warning: "#d29922",
                success: "#659ec4", // diff `+` marker becomes BLUE (colorblind shift)
                muted: "#858585",
                keyword: "#84d6ec",
                string: "#e4db82",
                comment: "#747160",
                number: "#b586f8",
                function: "#b3e053",
                type: "#b3e053"
            )
        ),
        BuiltInTheme(
            id: "light-daltonized",
            displayName: "Light mode (colorblind-friendly)",
            icon: "sun.haze.fill",
            description: "Light theme but diff `+` lines are blue instead of green — keeps add/remove distinguishable for red-green color vision.",
            approximateColors: ThemeColors(
                background: "#ffffff",
                foreground: "#333333",
                cursor: "#000000",
                selection: "#add6ff",
                accent: "#992c5c",
                error: "#be3536",
                warning: "#bf8700",
                success: "#325686", // diff `+` marker becomes BLUE
                muted: "#969896",
                keyword: "#992c5c",
                string: "#1f358c",
                comment: "#969896",
                number: "#3a84af",
                function: "#755e9f",
                type: "#3a84af"
            )
        ),
        BuiltInTheme(
            id: "dark-ansi",
            displayName: "Dark mode (ANSI colors only)",
            icon: "rectangle.split.3x1.fill",
            description: "Restricted to the terminal's basic ANSI 16-color palette — useful in environments where TrueColor isn't available, or to respect the terminal's own color scheme. Diff lines aren't background-highlighted.",
            approximateColors: ThemeColors(
                background: "#1e1e1e",
                foreground: "#d1d1d1",
                cursor: "#ffffff",
                selection: "#3a3a3a",
                accent: "#78f1f2",
                error: "#ec5a3a",
                warning: "#efef53",
                success: "#77ea51",
                muted: "#717171",
                keyword: "#78f1f2",
                string: "#efef53",
                comment: "#717171",
                number: "#6f48f6",
                function: "#efef53",
                type: "#78f1f2",
                ansiBlack: "#000000",
                ansiRed: "#ec5a3a",
                ansiGreen: "#77ea51",
                ansiYellow: "#efef53",
                ansiBlue: "#6f48f6",
                ansiMagenta: "#e454f0",
                ansiCyan: "#78f1f2",
                ansiWhite: "#d1d1d1"
            )
        ),
        BuiltInTheme(
            id: "light-ansi",
            displayName: "Light mode (ANSI colors only)",
            icon: "rectangle.split.3x1",
            description: "Restricted to the terminal's basic ANSI 16-color palette, on a light background. Diff lines aren't background-highlighted.",
            approximateColors: ThemeColors(
                background: "#ffffff",
                foreground: "#1a1a1a",
                cursor: "#000000",
                selection: "#cccccc",
                accent: "#ec5af7",
                error: "#ec5a3a",
                warning: "#efef53",
                success: "#77ea51",
                muted: "#909090",
                keyword: "#78f1f2",
                string: "#77ea51",
                comment: "#909090",
                number: "#6f48f6",
                function: "#efef53",
                type: "#78f1f2",
                ansiBlack: "#000000",
                ansiRed: "#ec5a3a",
                ansiGreen: "#77ea51",
                ansiYellow: "#efef53",
                ansiBlue: "#6f48f6",
                ansiMagenta: "#ec5af7",
                ansiCyan: "#78f1f2",
                ansiWhite: "#d1d1d1"
            )
        ),
    ]

    /// Starter color palettes shipped with CC Settings. Used by the "+ New"
    /// menu to scaffold a populated custom theme. Field names follow our
    /// best-effort guess at Claude Code's schema (which isn't publicly
    /// documented) — Claude Code may ignore fields it doesn't recognize.
    struct Preset: Identifiable {
        let id: String
        let displayName: String
        let suggestedFilename: String
        let colors: ThemeColors
    }

    static let starters: [Preset] = [
        Preset(
            id: "midnight",
            displayName: "Midnight",
            suggestedFilename: "midnight",
            colors: ThemeColors(
                name: "midnight",
                description: "Deep-black background with vibrant accents.",
                background: "#0a0a0a",
                foreground: "#e0e0e0",
                cursor: "#50fa7b",
                selection: "#44475a",
                accent: "#4a90e2",
                error: "#ff5555",
                warning: "#ffb86c",
                success: "#50fa7b",
                muted: "#6272a4",
                keyword: "#ff79c6",
                string: "#f1fa8c",
                comment: "#6272a4",
                number: "#bd93f9",
                function: "#50fa7b",
                type: "#8be9fd"
            )
        ),
        Preset(
            id: "solarized-dark",
            displayName: "Solarized Dark",
            suggestedFilename: "solarized-dark",
            colors: ThemeColors(
                name: "solarized-dark",
                description: "Ethan Schoonover's Solarized palette, dark variant.",
                background: "#002b36",
                foreground: "#839496",
                cursor: "#93a1a1",
                selection: "#073642",
                accent: "#268bd2",
                error: "#dc322f",
                warning: "#cb4b16",
                success: "#859900",
                muted: "#586e75",
                keyword: "#859900",
                string: "#2aa198",
                comment: "#586e75",
                number: "#d33682",
                function: "#268bd2",
                type: "#b58900"
            )
        ),
        Preset(
            id: "nord",
            displayName: "Nord",
            suggestedFilename: "nord",
            colors: ThemeColors(
                name: "nord",
                description: "Arctic, north-bluish color palette.",
                background: "#2e3440",
                foreground: "#d8dee9",
                cursor: "#d8dee9",
                selection: "#434c5e",
                accent: "#88c0d0",
                error: "#bf616a",
                warning: "#d08770",
                success: "#a3be8c",
                muted: "#4c566a",
                keyword: "#81a1c1",
                string: "#a3be8c",
                comment: "#616e88",
                number: "#b48ead",
                function: "#88c0d0",
                type: "#8fbcbb"
            )
        ),
    ]
}
