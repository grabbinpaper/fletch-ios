import SwiftUI
import SwiftData

struct ChecklistTabView: View {
    @Bindable var viewModel: ActiveVisitViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            if viewModel.checklistItems.isEmpty {
                ContentUnavailableView(
                    "No Checklist",
                    systemImage: "checklist",
                    description: Text("No checklist template configured for this service.")
                )
                .padding(.top, 60)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(groupedSections, id: \.0) { section, items in
                        if let section {
                            Text(section)
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.top, 16)
                                .padding(.bottom, 4)
                        }

                        ForEach(items, id: \.itemId) { item in
                            ChecklistItemRow(
                                item: item,
                                isReadOnly: viewModel.booking.visitStatus == "completed",
                                onStatusChange: { status in
                                    viewModel.updateChecklistItem(
                                        item,
                                        status: status,
                                        context: modelContext
                                    )
                                },
                                onNotesChange: { notes in
                                    viewModel.updateChecklistItem(
                                        item,
                                        status: item.status,
                                        notes: notes,
                                        context: modelContext
                                    )
                                }
                            )
                        }
                    }
                }
                .padding(.vertical)
            }
        }
    }

    private var groupedSections: [(String?, [CachedChecklistItem])] {
        let grouped = Dictionary(grouping: viewModel.checklistItems) { $0.section }
        let sortedKeys = grouped.keys.sorted { ($0 ?? "") < ($1 ?? "") }
        return sortedKeys.map { key in (key, grouped[key]!.sorted { $0.displayOrder < $1.displayOrder }) }
    }
}

struct ChecklistItemRow: View {
    let item: CachedChecklistItem
    let isReadOnly: Bool
    let onStatusChange: (String) -> Void
    let onNotesChange: (String) -> Void

    @State private var showNotes = false
    @State private var notesText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Status icon
                statusIcon
                    .frame(width: 24)

                Text(item.label)
                    .font(.subheadline)
                    .strikethrough(item.status == "skipped" || item.status == "not_applicable")
                    .foregroundStyle(item.status == "skipped" ? .secondary : .primary)

                Spacer()

                if !isReadOnly {
                    Menu {
                        Button { onStatusChange("passed") } label: {
                            Label("Pass", systemImage: "checkmark.circle.fill")
                        }
                        Button { onStatusChange("failed") } label: {
                            Label("Fail", systemImage: "xmark.circle.fill")
                        }
                        Button { onStatusChange("skipped") } label: {
                            Label("Skip", systemImage: "arrow.right.circle")
                        }
                        Button { onStatusChange("not_applicable") } label: {
                            Label("N/A", systemImage: "minus.circle")
                        }
                        Divider()
                        Button { showNotes.toggle() } label: {
                            Label("Add Note", systemImage: "note.text")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let notes = item.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 28)
            }

            if showNotes {
                HStack {
                    TextField("Notes...", text: $notesText)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    Button("Save") {
                        onNotesChange(notesText)
                        showNotes = false
                    }
                    .font(.caption)
                }
                .padding(.leading, 28)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .onAppear {
            notesText = item.notes ?? ""
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case "passed":
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case "failed":
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        case "skipped":
            Image(systemName: "arrow.right.circle")
                .foregroundStyle(.orange)
        case "not_applicable":
            Image(systemName: "minus.circle")
                .foregroundStyle(.gray)
        default:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        }
    }
}
