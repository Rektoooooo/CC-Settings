import SwiftUI

struct RenameProfileSheet: View {
    @Environment(\.dismiss) private var dismiss

    let profile: SettingsProfile
    let onRename: (String, String) -> Void

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
                    Image(systemName: "pencil")
                        .foregroundColor(.accentColor)
                    Text("Rename Profile")
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
                        TextField("Profile name", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.subheadline.bold())
                        TextField("Optional description", text: $description)
                            .textFieldStyle(.roundedBorder)
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
                Button("Save") {
                    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
                    onRename(trimmedName, trimmedDesc)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(minWidth: 400, idealWidth: 500, maxWidth: 600,
               minHeight: 200, idealHeight: 300, maxHeight: 400)
        .onAppear {
            name = profile.name
            description = profile.description
        }
    }
}
