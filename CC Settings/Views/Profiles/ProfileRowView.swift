import SwiftUI

struct ProfileRowView: View {
    let profile: SettingsProfile
    let onLoad: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(profile.name)
                        .font(.headline)
                    Spacer()
                    Text(profile.updatedAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if !profile.description.isEmpty {
                    Text(profile.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Text(profile.settingsSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button {
                onLoad()
            } label: {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .help("Load this profile")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassContainer()
    }
}
