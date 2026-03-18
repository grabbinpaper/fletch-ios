import SwiftUI

struct AddBacksplashSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (BacksplashFormData) -> Void

    @State private var location = "back"
    @State private var heightText = ""
    @State private var lengthText = ""

    private let locations = ["left", "back", "right"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    Picker("Wall", selection: $location) {
                        Text("Left Wall").tag("left")
                        Text("Back Wall").tag("back")
                        Text("Right Wall").tag("right")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Dimensions") {
                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("inches", text: $heightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 80)
                        Text("in")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Length")
                        Spacer()
                        TextField("inches", text: $lengthText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 80)
                        Text("in")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add Backsplash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(BacksplashFormData(
                            location: location,
                            heightIn: Double(heightText),
                            lengthIn: Double(lengthText)
                        ))
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
