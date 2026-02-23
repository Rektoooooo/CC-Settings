import SwiftUI

struct RemoteConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var gitService: GitService

    @State private var remoteName: String = "origin"
    @State private var remoteURL: String = ""
    @State private var validationError: String?
    @State private var saveError: String?
    @State private var isSaving = false

    private var isEditing: Bool {
        gitService.remoteURL != nil
    }

    private var canSave: Bool {
        !remoteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && validationError == nil
            && !isSaving
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "link.badge.plus")
                        .foregroundColor(.accentColor)
                    Text(isEditing ? "Edit Remote" : "Add Remote")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Remote URL
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Remote URL")
                            .font(.subheadline.bold())
                        TextField("https://github.com/user/claude-settings.git", text: $remoteURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: remoteURL) { _, newValue in
                                validateURL(newValue)
                            }

                        if let error = validationError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        Text("Supports HTTPS and SSH URLs (e.g., git@github.com:user/repo.git)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let error = saveError {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    if isEditing {
                        // Show current remote
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Remote")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(gitService.remoteURL ?? "None")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassContainer()

                        Button(role: .destructive) {
                            _ = gitService.removeRemote()
                            dismiss()
                        } label: {
                            Label("Remove Remote", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(isEditing ? "Update Remote" : "Add Remote") {
                    saveRemote()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding()
        }
        .frame(width: 500, height: 300)
        .onAppear {
            if let existing = gitService.remoteURL {
                remoteURL = existing
            }
        }
    }

    private func validateURL(_ url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            validationError = nil
            return
        }

        // Accept HTTPS URLs, SSH URLs, and git:// URLs
        let httpsPattern = #"^https?://.+/.+$"#
        let sshPattern = #"^git@.+:.+/.+$"#
        let gitPattern = #"^git://.+/.+$"#

        let isValid = trimmed.range(of: httpsPattern, options: .regularExpression) != nil
            || trimmed.range(of: sshPattern, options: .regularExpression) != nil
            || trimmed.range(of: gitPattern, options: .regularExpression) != nil

        validationError = isValid ? nil : "Please enter a valid git remote URL."
    }

    private func saveRemote() {
        let trimmed = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        saveError = nil
        isSaving = true
        let success = gitService.addRemote(url: trimmed)
        isSaving = false
        if success {
            dismiss()
        } else {
            saveError = "Failed to add remote. Check that the URL is valid and git is accessible."
        }
    }
}
