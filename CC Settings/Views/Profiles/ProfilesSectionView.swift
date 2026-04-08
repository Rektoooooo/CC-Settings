import SwiftUI

struct ProfilesSectionView: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @EnvironmentObject var profileManager: ProfileManager

    @State private var showSaveSheet = false
    @State private var showLoadAlert = false
    @State private var showDeleteAlert = false
    @State private var showOverwriteAlert = false
    @State private var showRenameSheet = false
    @State private var selectedProfile: SettingsProfile?
    @State private var errorMessage: String?

    var body: some View {
        Section {
            SettingsSection(title: "Profiles", description: "Save and load settings snapshots.") {
                if profileManager.profiles.isEmpty {
                    emptyState
                } else {
                    profilesList
                }

                Button {
                    showSaveSheet = true
                } label: {
                    Label("Save Current Settings as Profile", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
            }
        }
        .sheet(isPresented: $showSaveSheet) {
            SaveProfileSheet { name, description in
                do {
                    try profileManager.saveCurrentAsProfile(name: name, description: description)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            if let profile = selectedProfile {
                RenameProfileSheet(profile: profile) { newName, newDescription in
                    var updated = profile
                    updated.name = newName
                    updated.description = newDescription
                    do {
                        try profileManager.updateProfile(updated)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
        .alert("Load Profile?", isPresented: $showLoadAlert, presenting: selectedProfile) { profile in
            Button("Cancel", role: .cancel) { }
            Button("Load") {
                profileManager.loadProfile(profile, into: configManager)
            }
        } message: { profile in
            Text("This will replace all current settings with \"\(profile.name)\". This cannot be undone.")
        }
        .alert("Delete Profile?", isPresented: $showDeleteAlert, presenting: selectedProfile) { profile in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                do {
                    try profileManager.deleteProfile(profile)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } message: { profile in
            Text("Are you sure you want to delete \"\(profile.name)\"?")
        }
        .alert("Overwrite Profile?", isPresented: $showOverwriteAlert, presenting: selectedProfile) { profile in
            Button("Cancel", role: .cancel) { }
            Button("Overwrite") {
                do {
                    try profileManager.overwriteProfile(profile)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } message: { profile in
            Text("This will replace \"\(profile.name)\" with the current settings.")
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up.slash")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("No saved profiles")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
            Spacer()
        }
    }

    @ViewBuilder
    private var profilesList: some View {
        VStack(spacing: 8) {
            ForEach(profileManager.profiles) { profile in
                ProfileRowView(profile: profile) {
                        selectedProfile = profile
                        showLoadAlert = true
                    }
                    .contextMenu {
                        Button {
                            selectedProfile = profile
                            showLoadAlert = true
                        } label: {
                            Label("Load Profile", systemImage: "arrow.down.circle")
                        }

                        Divider()

                        Button {
                            selectedProfile = profile
                            showRenameSheet = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }

                        Button {
                            do {
                                try profileManager.duplicateProfile(profile, newName: "\(profile.name) Copy")
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        } label: {
                            Label("Duplicate", systemImage: "doc.on.doc")
                        }

                        Button {
                            selectedProfile = profile
                            showOverwriteAlert = true
                        } label: {
                            Label("Overwrite with Current Settings", systemImage: "arrow.triangle.2.circlepath")
                        }

                        Divider()

                        Button(role: .destructive) {
                            selectedProfile = profile
                            showDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .onTapGesture(count: 2) {
                        selectedProfile = profile
                        showLoadAlert = true
                    }
            }
        }
    }
}
