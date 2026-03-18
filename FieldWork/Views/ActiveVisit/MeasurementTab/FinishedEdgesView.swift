import SwiftUI

struct FinishedEdgesView: View {
    @Binding var finishedEdges: String
    let isReadOnly: Bool

    private let allEdges = ["front", "back", "left", "right"]

    private var selectedEdges: Set<String> {
        Set(finishedEdges.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Finished Edges")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if isReadOnly {
                if selectedEdges.isEmpty {
                    Text("None")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(selectedEdges.sorted().map(\.capitalized).joined(separator: ", "))
                        .font(.subheadline)
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(allEdges, id: \.self) { edge in
                        let isSelected = selectedEdges.contains(edge)
                        Button {
                            toggle(edge)
                        } label: {
                            Text(edge.capitalized)
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(isSelected ? Color.blue : Color(.systemGray5))
                                .foregroundStyle(isSelected ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }
        }
    }

    private func toggle(_ edge: String) {
        var current = selectedEdges
        if current.contains(edge) {
            current.remove(edge)
        } else {
            current.insert(edge)
        }
        // Sort for stable comma-separated output
        let sorted = allEdges.filter { current.contains($0) }
        finishedEdges = sorted.joined(separator: ",")
    }
}
