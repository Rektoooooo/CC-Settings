import XCTest

final class SlashCommandFrontmatterTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("cc-cmd-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func parse(_ text: String) throws -> SlashCommand {
        let url = dir.appendingPathComponent("cmd.md")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return try XCTUnwrap(SlashCommand.parse(from: url))
    }

    private let sample = """
    ---
    # a comment kept in place
    description: |
      Review the diff
      carefully
    model: claude-opus-4
    allowed-tools:
      - Bash(git:*)
      - Read
    disable-model-invocation: true
    hooks:
      PreToolUse:
        - matcher: Bash
    argument-hint: [file]
    ---

    Do the thing with $ARGUMENTS.
    """

    func testUnchangedCommandRoundTripsByteForByte() throws {
        let command = try parse(sample)
        XCTAssertEqual(command.toMarkdown(), sample)
    }

    func testListAndBlockScalarAreReadForDisplay() throws {
        let command = try parse(sample)
        XCTAssertEqual(command.allowedTools, ["Bash(git:*)", "Read"])
        XCTAssertEqual(command.description, "Review the diff carefully")
        XCTAssertEqual(command.argumentHint, "[file]")
        XCTAssertEqual(command.body, "Do the thing with $ARGUMENTS.")
    }

    func testEditingOneKeyChangesOnlyThatKey() throws {
        var command = try parse(sample)
        command.argumentHint = "[path]"
        let out = command.toMarkdown()
        XCTAssertEqual(out, sample.replacingOccurrences(of: "argument-hint: [file]", with: "argument-hint: [path]"))
    }

    func testEditingBlockScalarReplacesWholeBlockAndKeepsRest() throws {
        var command = try parse(sample)
        command.description = "Short"
        let out = command.toMarkdown()
        XCTAssertTrue(out.contains("description: Short\nmodel: claude-opus-4"))
        XCTAssertFalse(out.contains("Review the diff"))
        XCTAssertTrue(out.contains("  - Bash(git:*)\n  - Read"))
        XCTAssertTrue(out.contains("hooks:\n  PreToolUse:\n    - matcher: Bash"))
        XCTAssertTrue(out.contains("# a comment kept in place"))
    }

    func testEditingListKeyRewritesItAndKeepsUnknownKeys() throws {
        var command = try parse(sample)
        command.allowedTools = ["Read"]
        let out = command.toMarkdown()
        XCTAssertTrue(out.contains("allowed-tools: Read\ndisable-model-invocation: true"))
        XCTAssertFalse(out.contains("Bash(git:*)"))
        XCTAssertTrue(out.contains("model: claude-opus-4"))
    }

    func testClearingAKeyRemovesItsBlock() throws {
        var command = try parse(sample)
        command.allowedTools = []
        let out = command.toMarkdown()
        XCTAssertFalse(out.contains("allowed-tools"))
        XCTAssertFalse(out.contains("Bash(git:*)"))
    }

    func testCRLFIsPreserved() throws {
        let crlf = sample.replacingOccurrences(of: "\n", with: "\r\n")
        var command = try parse(crlf)
        XCTAssertEqual(command.allowedTools, ["Bash(git:*)", "Read"])
        XCTAssertEqual(command.toMarkdown(), crlf)
        command.argumentHint = "[path]"
        XCTAssertEqual(command.toMarkdown(), crlf.replacingOccurrences(of: "argument-hint: [file]", with: "argument-hint: [path]"))
    }

    func testNewCommandWithoutFrontmatterGetsOne() throws {
        var command = try parse("Just a body\n")
        XCTAssertEqual(command.toMarkdown(), "Just a body\n")
        command.description = "Hi"
        XCTAssertEqual(command.toMarkdown(), "---\ndescription: Hi\n---\n\nJust a body\n")
    }

    func testInlineCommaToolsStillWork() throws {
        var command = try parse("---\nallowed-tools: Bash, Read\n---\nbody")
        XCTAssertEqual(command.allowedTools, ["Bash", "Read"])
        command.allowedTools.append("Grep")
        XCTAssertEqual(command.toMarkdown(), "---\nallowed-tools: Bash, Read, Grep\n---\nbody")
    }
}
