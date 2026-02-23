import SwiftUI

struct GitInitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var gitService: GitService

    @State private var isInitializing = false
    @State private var initResult: InitResult?

    private enum InitResult {
        case success
        case failure(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundColor(.accentColor)
                    Text("Initialize Repository")
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
                    // Explanation
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What will happen")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 6) {
                            InitStepRow(number: 1, text: "A git repository will be created in \(gitService.repoPath.path)")
                            InitStepRow(number: 2, text: "A .gitignore file will be created to exclude large session files")
                            InitStepRow(number: 3, text: "All current settings files will be committed")
                        }
                    }

                    // .gitignore preview
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text")
                                .foregroundColor(.secondary)
                            Text(".gitignore preview")
                                .font(.subheadline.bold())
                        }

                        ScrollView {
                            Text(gitService.defaultGitignore())
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 140)
                        .glassContainer()
                    }

                    // Directory info
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(gitService.repoPath.path)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassContainer()

                    // Result
                    if let result = initResult {
                        switch result {
                        case .success:
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Repository initialized successfully.")
                                    .font(.subheadline)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassBanner(tint: .green)

                        case .failure(let message):
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(message)
                                    .font(.subheadline)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassBanner(tint: .red)
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Spacer()

                if isInitializing {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 8)
                }

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                if case .success = initResult {
                    Button("Done") {
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Initialize") {
                        performInit()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isInitializing)
                }
            }
            .padding()
        }
        .frame(width: 550, height: 450)
    }

    private func performInit() {
        isInitializing = true
        initResult = nil

        Task {
            let success = await gitService.initRepo()

            isInitializing = false
            if success {
                initResult = .success
            } else {
                initResult = .failure("Failed to initialize the repository. Check that git is installed and \(gitService.repoPath.path) is accessible.")
            }
        }
    }
}

// MARK: - InitStepRow

private struct InitStepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.accentColor)
                .frame(width: 20, alignment: .trailing)
            Text(text)
                .font(.subheadline)
        }
    }
}
