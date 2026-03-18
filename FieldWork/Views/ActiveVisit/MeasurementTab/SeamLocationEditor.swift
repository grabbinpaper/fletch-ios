import SwiftUI

struct SeamLocationEditor: View {
    @Binding var seamLocations: [String]
    let isReadOnly: Bool

    @State private var newSeamText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Seam Locations")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if !seamLocations.isEmpty {
                    Text("(\(seamLocations.count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Tags
            if !seamLocations.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(seamLocations.enumerated()), id: \.offset) { index, location in
                        SeamTag(text: "@ \(location)\"", isReadOnly: isReadOnly) {
                            seamLocations.remove(at: index)
                        }
                    }
                }
            }

            // Add new
            if !isReadOnly {
                HStack(spacing: 8) {
                    Text("@")
                        .foregroundStyle(.secondary)
                    TextField("inches", text: $newSeamText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 80)
                    Button {
                        let trimmed = newSeamText.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        seamLocations.append(trimmed)
                        newSeamText = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                    .disabled(newSeamText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

private struct SeamTag: View {
    let text: String
    let isReadOnly: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
            if !isReadOnly {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .clipShape(Capsule())
    }
}

// FlowLayout is defined in SiteConditionTabView.swift and reused here
