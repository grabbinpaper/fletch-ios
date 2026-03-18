import SwiftUI

struct EdgeProfilePicker: View {
    let currentName: String?
    let quotedName: String?
    let isChanged: Bool
    let isReadOnly: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Edge Profile")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if isChanged {
                    StatusBadge(text: "Changed", color: .orange)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentName ?? "Not set")
                        .font(.subheadline)
                    if isChanged, let quoted = quotedName {
                        Text("Quoted: \(quoted)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if !isReadOnly {
                    Button("Change") { onSelect() }
                        .font(.caption)
                        .buttonStyle(.bordered)
                }
            }
        }
    }
}

/// Sheet for selecting an edge profile from a list
struct EdgeProfileListSheet: View {
    let profiles: [EdgeProfileOption]
    let currentId: UUID?
    let onSelect: (EdgeProfileOption) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(profiles) { profile in
                Button {
                    onSelect(profile)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(profile.name)
                                .foregroundStyle(.primary)
                            if let code = profile.code {
                                Text(code)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if profile.id == currentId {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle("Edge Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct EdgeProfileOption: Identifiable {
    let id: UUID
    let name: String
    let code: String?
}
