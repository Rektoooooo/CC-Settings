import SwiftUI

struct SaveProfileSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (String, String) -> Void

    @State private var name: String = ""
    @State private var description: String = ""

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(.accentColor)
                    Text("Save Profile")
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Profile Name")
                            .font(.subheadline.bold())
                        TextField("e.g. Work, Personal, Coding", text: $name)
                            .textFieldStyle(.roundedBorder)
                        Text("A name to identify this settings snapshot.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.subheadline.bold())
                        TextField("Optional description", text: $description)
                            .textFieldStyle(.roundedBorder)
                        Text("Briefly describe what this profile is for.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save Profile") {
                    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(trimmedName, trimmedDesc)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(minWidth: 400, idealWidth: 500, maxWidth: 600,
               minHeight: 250, idealHeight: 350, maxHeight: 450)
    }
}
