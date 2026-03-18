import SwiftUI

/// A checklist row that presents a yes/no toggle switch.
/// Used for field_type == "toggle" or "checkbox".
struct ChecklistToggleRow: View {
    let item: CachedChecklistItem
    let isReadOnly: Bool
    let onUpdate: (String, String?) -> Void

    private var isOn: Bool {
        item.responseValue == "true" || item.status == "passed"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.label)
                    .font(.subheadline)

                Spacer()

                if isReadOnly {
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isOn ? .green : .secondary)
                } else {
                    Toggle("", isOn: Binding(
                        get: { isOn },
                        set: { newValue in
                            let status = newValue ? "passed" : "pending"
                            let response = newValue ? "true" : "false"
                            onUpdate(status, response)
                        }
                    ))
                    .labelsHidden()
                    .tint(.green)
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
}
