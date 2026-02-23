import SwiftUI

struct JSONFileViewer: View {
    let file: ClaudeFile
    let readOnly: Bool

    @State private var content: String = ""
    @State private var originalContent: String = ""
    @State private var validationError: String? = nil
    @State private var viewMode: JSONViewMode = .highlighted

    private var hasChanges: Bool {
        content != originalContent
    }

    private var isValidJSON: Bool {
        validationError == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            FileViewerToolbar(
                file: file,
                readOnly: readOnly,
                hasChanges: hasChanges && isValidJSON,
                onSave: save,
                onRevert: revert
            ) {
                HStack(spacing: 6) {
                    // Validation indicator
                    if isValidJSON {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Valid JSON")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text(validationError ?? "Invalid JSON")
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(1)
                    }

                    Divider()
                        .frame(height: 16)

                    // Format button
                    Button("Format") {
                        formatJSON()
                    }
                    .disabled(!isValidJSON || readOnly)

                    // View mode picker
                    Picker("", selection: $viewMode) {
                        ForEach(JSONViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
            }

            Divider()

            switch viewMode {
            case .highlighted:
                if readOnly {
                    ReadOnlyBanner()
                }
                highlightedView
            case .source:
                if readOnly {
                    ReadOnlyBanner()
                    ScrollView {
                        Text(content)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .textSelection(.enabled)
                    }
                } else {
                    TextEditor(text: $content)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(4)
                        .onChange(of: content) {
                            validateJSON()
                        }
                }
            }
        }
        .id(file.id)
        .onAppear(perform: loadContent)
        .onChange(of: file.id) {
            loadContent()
        }
    }

    // MARK: - Highlighted JSON View

    @ViewBuilder
    private var highlightedView: some View {
        ScrollView {
            if isValidJSON, let data = content.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) {
                JSONValueView(value: parsed, depth: 0)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            } else {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Data

    private func loadContent() {
        if let text = try? String(contentsOf: file.path, encoding: .utf8) {
            content = text
            originalContent = text
        } else {
            content = ""
            originalContent = ""
        }
        validateJSON()
    }

    private func validateJSON() {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationError = "Empty content"
            return
        }
        guard let data = content.data(using: .utf8) else {
            validationError = "Invalid encoding"
            return
        }
        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [])
            validationError = nil
        } catch {
            validationError = error.localizedDescription
        }
    }

    private func formatJSON() {
        guard let data = content.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys]
              ),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return
        }
        content = prettyString
    }

    private func save() {
        guard isValidJSON else { return }
        do {
            try content.write(to: file.path, atomically: true, encoding: .utf8)
            originalContent = content
        } catch {
            print("Failed to save file: \(error)")
        }
    }

    private func revert() {
        content = originalContent
        validateJSON()
    }
}

// MARK: - View Mode

enum JSONViewMode: String, CaseIterable {
    case highlighted = "Highlighted"
    case source = "Source"
}

// MARK: - Recursive JSON Value Renderer

private struct JSONValueView: View {
    let value: Any
    let depth: Int

    var body: some View {
        renderValue(value)
    }

    @ViewBuilder
    private func renderValue(_ value: Any) -> some View {
        if let dict = value as? [String: Any] {
            JSONObjectView(dict: dict, depth: depth)
        } else if let array = value as? [Any] {
            JSONArrayView(array: array, depth: depth)
        } else if let string = value as? String {
            Text("\"\(string)\"")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.green)
        } else if let number = value as? NSNumber {
            if CFBooleanGetTypeID() == CFGetTypeID(number) {
                Text(number.boolValue ? "true" : "false")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.orange)
            } else {
                Text("\(number)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.cyan)
            }
        } else if value is NSNull {
            Text("null")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .italic()
        } else {
            Text("\(String(describing: value))")
                .font(.system(.body, design: .monospaced))
        }
    }
}

// MARK: - JSON Object (Dictionary)

private struct JSONObjectView: View {
    let dict: [String: Any]
    let depth: Int

    @State private var isExpanded: Bool = true

    private var sortedKeys: [String] {
        dict.keys.sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 10)

                    Text("{")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)

                    if !isExpanded {
                        Text("\(dict.count) key\(dict.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("}")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(sortedKeys, id: \.self) { key in
                        JSONKeyValueRow(key: key, value: dict[key]!, depth: depth + 1)
                    }
                }
                .padding(.leading, 16)

                Text("}")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.leading, 14)
            }
        }
    }
}

// MARK: - JSON Array

private struct JSONArrayView: View {
    let array: [Any]
    let depth: Int

    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 10)

                    Text("[")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)

                    if !isExpanded {
                        Text("\(array.count) item\(array.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("]")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(array.enumerated()), id: \.offset) { index, element in
                        HStack(alignment: .top, spacing: 4) {
                            Text("\(index)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(minWidth: 20, alignment: .trailing)

                            JSONValueView(value: element, depth: depth + 1)
                        }
                    }
                }
                .padding(.leading, 16)

                Text("]")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.leading, 14)
            }
        }
    }
}

// MARK: - Key-Value Row

private struct JSONKeyValueRow: View {
    let key: String
    let value: Any
    let depth: Int

    private var isContainer: Bool {
        value is [String: Any] || value is [Any]
    }

    var body: some View {
        if isContainer {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Text("\"\(key)\"")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.purple)
                    Text(": ")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                JSONValueView(value: value, depth: depth)
                    .padding(.leading, 4)
            }
        } else {
            HStack(alignment: .top, spacing: 0) {
                Text("\"\(key)\"")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.purple)
                Text(": ")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                JSONValueView(value: value, depth: depth)
            }
        }
    }
}
