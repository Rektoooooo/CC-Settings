import SwiftUI

struct MCPServerDetailView: View {
    let server: MCPServerConfig
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    @State private var showDeleteAlert = false

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: 8) {
                    Image(systemName: server.transportType.icon)
                        .foregroundColor(server.transportType == .stdio ? .themeAccent : .purple)
                        .font(.title3)

                    Text(server.id)
                        .font(.headline.monospaced())
                        .lineLimit(1)

                    Text(server.transportType.displayName)
                        .font(.caption.monospaced())
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(server.transportType == .stdio ? Color.themeAccent : Color.purple)
                        .cornerRadius(4)

                    Spacer()

                    Button {
                        onEdit?()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Delete server")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassToolbar()

                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Server Info Grid
                        serverInfoGrid

                        // Arguments
                        if let args = server.args, !args.isEmpty {
                            argumentsSection(args)
                        }

                        // Environment Variables
                        if let env = server.env, !env.isEmpty {
                            envVarsSection(env)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(minWidth: 400)
        .alert("Delete Server", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Are you sure you want to delete \"\(server.id)\"? This cannot be undone.")
        }
    }

    // MARK: - Info Grid

    @ViewBuilder
    private var serverInfoGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Server Info")
                .font(.subheadline.bold())

            LazyVGrid(columns: [
                GridItem(.fixed(100), alignment: .trailing),
                GridItem(.flexible(), alignment: .leading)
            ], spacing: 6) {
                Text("Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(server.id)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)

                Text("Transport")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: server.transportType.icon)
                        .font(.caption)
                    Text(server.transportType.displayName)
                        .font(.caption)
                }

                if let command = server.command {
                    Text("Command")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(command)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }

                if let url = server.url {
                    Text("URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(url)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .lineLimit(2)
                }
            }
        }
        .padding(12)
        .glassContainer()
    }

    // MARK: - Arguments Section

    @ViewBuilder
    private func argumentsSection(_ args: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Arguments (\(args.count))")
                .font(.subheadline.bold())

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(args.enumerated()), id: \.offset) { index, arg in
                    HStack(spacing: 8) {
                        Text("\(index)")
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                            .frame(width: 20, alignment: .trailing)
                        Text(arg)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .lineLimit(2)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassContainer()
        }
    }

    // MARK: - Environment Variables Section

    @ViewBuilder
    private func envVarsSection(_ env: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Environment Variables (\(env.count))")
                .font(.subheadline.bold())

            LazyVGrid(columns: [
                GridItem(.fixed(150), alignment: .leading),
                GridItem(.flexible(), alignment: .leading)
            ], spacing: 6) {
                Text("Key")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Text("Value")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                ForEach(env.keys.sorted(), id: \.self) { key in
                    Text(key)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                    Text(env[key] ?? "")
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .lineLimit(1)
                }
            }
            .padding(12)
            .glassContainer()
        }
    }
}
