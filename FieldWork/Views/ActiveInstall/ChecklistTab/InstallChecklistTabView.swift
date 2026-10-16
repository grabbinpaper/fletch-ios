import SwiftUI
import SwiftData

struct InstallChecklistTabView: View {
    @Bindable var viewModel: ActiveInstallViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            if viewModel.checklistItems.isEmpty {
                ContentUnavailableView(
                    "No Checklist",
                    systemImage: "checklist",
                    description: Text("No checklist configured for this visit type.")
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
                            checklistRow(for: item)
                            Divider()
                                .padding(.leading)
                        }
                    }
                }
                .padding(.vertical)
            }
        }
    }

    @ViewBuilder
    private func checklistRow(for item: CachedChecklistItem) -> some View {
        let isReadOnly = viewModel.booking.visitStatus == "completed"

        switch item.fieldType {
        case "toggle", "checkbox":
            ChecklistToggleRow(
                item: item,
                isReadOnly: isReadOnly,
                onUpdate: { status, responseValue in
                    viewModel.updateChecklistItem(
                        item,
                        status: status,
                        responseValue: responseValue,
                        context: modelContext
                    )
                }
            )

        case "single_select":
            ChecklistPickerRow(
                item: item,
                isReadOnly: isReadOnly,
                onUpdate: { status, responseValue in
                    viewModel.updateChecklistItem(
                        item,
                        status: status,
                        responseValue: responseValue,
                        context: modelContext
                    )
                }
            )

        case "text":
            ChecklistTextRow(
                item: item,
                isReadOnly: isReadOnly,
                onUpdate: { status, responseValue in
                    viewModel.updateChecklistItem(
                        item,
                        status: status,
                        responseValue: responseValue,
                        context: modelContext
                    )
                }
            )

        default:
            ChecklistPassFailRow(
                item: item,
                isReadOnly: isReadOnly,
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
                },
                photoChip: item.requiresPhoto ? AnyView(
                    ChecklistPhotoChip(
                        photoCount: item.photoCount,
                        isRequired: item.requiresPhoto,
                        onTap: {
                            viewModel.selectedTab = .photos
                        }
                    )
                ) : nil,
                onTakePhoto: {
                    viewModel.selectedTab = .photos
                }
            )
        }
    }

    private var groupedSections: [(String?, [CachedChecklistItem])] {
        let grouped = Dictionary(grouping: viewModel.checklistItems) { $0.section }
        let sortedKeys = grouped.keys.sorted { ($0 ?? "") < ($1 ?? "") }
        return sortedKeys.map { key in (key, grouped[key]!.sorted { $0.displayOrder < $1.displayOrder }) }
    }
}
