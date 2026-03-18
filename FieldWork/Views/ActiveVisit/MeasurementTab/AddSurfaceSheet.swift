import SwiftUI

struct AddSurfaceSheet: View {
    let rooms: [RoomInfo]
    let onAdd: (String, String?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var surfaceName = ""
    @State private var roomMode: RoomMode = .existing
    @State private var selectedRoom: String?
    @State private var newRoomName = ""
    @State private var isSubmitting = false

    private enum RoomMode: String, CaseIterable {
        case existing = "Existing"
        case new = "New Room"
    }

    /// The room name that will be passed to the callback.
    private var resolvedRoomName: String? {
        switch roomMode {
        case .existing: return selectedRoom
        case .new:
            let trimmed = newRoomName.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Surface") {
                    TextField("Name (e.g. Kitchen Island)", text: $surfaceName)
                        .textInputAutocapitalization(.words)
                }

                Section("Room") {
                    Picker("Room", selection: $roomMode) {
                        ForEach(RoomMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch roomMode {
                    case .existing:
                        Picker("Select Room", selection: $selectedRoom) {
                            Text("None").tag(String?.none)
                            ForEach(rooms) { room in
                                Text(room.name).tag(Optional(room.name))
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    case .new:
                        TextField("Room name (e.g. Bathroom)", text: $newRoomName)
                            .textInputAutocapitalization(.words)
                    }
                }
            }
            .navigationTitle("Add Surface")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        isSubmitting = true
                        onAdd(surfaceName.trimmingCharacters(in: .whitespaces), resolvedRoomName)
                        dismiss()
                    }
                    .disabled(surfaceName.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                // Default to new-room if no existing rooms to pick from
                if rooms.isEmpty { roomMode = .new }
            }
        }
    }
}

struct RoomInfo: Identifiable {
    let id: UUID
    let name: String
}
