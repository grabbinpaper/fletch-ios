import SwiftUI

/// A checklist row that presents a single-select picker from options_json.
/// Used for field_type == "single_select".
struct ChecklistPickerRow: View {
    let item: CachedChecklistItem
    let isReadOnly: Bool
    let onUpdate: (String, String?) -> Void

    private var options: [(key: String, label: String)] {
        // Parse options from the template item's options stored in responseValue context
        // Options are stored as JSON array: [{"key":"k","label":"L"}, ...]
        // For now, parse from a known pattern or fall back to empty
        guard let section = item.section else { return [] }
        // Options are embedded in the field — we read from a helper
        return []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.label)
                    .font(.subheadline)

                Spacer()

                if isReadOnly {
                    Text(item.responseValue ?? "Not set")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Menu {
                        ForEach(parsedOptions, id: \.key) { option in
                            Button {
                                onUpdate("passed", option.key)
                            } label: {
                                HStack {
                                    Text(option.label)
                                    if item.responseValue == option.key {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }

                        if item.responseValue != nil {
                            Divider()
                            Button(role: .destructive) {
                                onUpdate("pending", nil)
                            } label: {
                                Label("Clear", systemImage: "xmark.circle")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedLabel ?? "Select...")
                                .font(.subheadline)
                                .foregroundStyle(item.responseValue != nil ? .primary : .secondary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            if let notes = item.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private var selectedLabel: String? {
        guard let value = item.responseValue else { return nil }
        return parsedOptions.first { $0.key == value }?.label ?? value
    }

    /// Parse options from the label convention: "Label [opt1:Label1,opt2:Label2]"
    /// Or from a JSONB string if available
    private var parsedOptions: [(key: String, label: String)] {
        // Try parsing from notes field which may contain options JSON
        // For single_select items, the view model could set options differently
        // Use a simple convention: options embedded as pipe-separated in the label suffix
        // e.g., "Cabinet condition|good:Good,fair:Fair,poor:Poor"

        let label = item.label
        if let pipeIndex = label.firstIndex(of: "|") {
            let optionsStr = String(label[label.index(after: pipeIndex)...])
            return optionsStr.split(separator: ",").compactMap { part in
                let kv = part.split(separator: ":", maxSplits: 1)
                guard kv.count == 2 else { return nil }
                return (key: String(kv[0]), label: String(kv[1]))
            }
        }

        return []
    }
}
