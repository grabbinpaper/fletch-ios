import SwiftUI

struct AddSurfaceSheet: View {
    let rooms: [RoomInfo]
    let onAdd: (String, String?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var surfaceName = ""
    @State private var selectedRoom: String?
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Surface") {
                    TextField("Name (e.g. Kitchen Island)", text: $surfaceName)
                        .textInputAutocapitalization(.words)
                }

                Section("Room (Optional)") {
                    Picker("Room", selection: $selectedRoom) {
                        Text("None").tag(String?.none)
                        ForEach(rooms) { room in
                            Text(room.name).tag(Optional(room.name))
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
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
                        onAdd(surfaceName.trimmingCharacters(in: .whitespaces), selectedRoom)
                        dismiss()
                    }
                    .disabled(surfaceName.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct RoomInfo: Identifiable {
    let id: UUID
    let name: String
}
