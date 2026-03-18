import SwiftUI

struct CutoutFormData {
    let cutoutType: String
    let make: String?
    let modelName: String?
    let sinkInstallType: String?
    let faucetHoles: Int?
    let bringToShop: Bool
    let cooktopOnsite: Bool?
    let count: Int
    let locationNote: String?
}

struct AddCutoutSheet: View {
    let onAdd: (CutoutFormData) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var cutoutType = "sink"
    @State private var make = ""
    @State private var modelText = ""
    @State private var count = 1
    @State private var locationNote = ""

    // Sink-specific
    @State private var sinkInstallType = "undermount"
    @State private var faucetHoles = 0
    @State private var bringToShop = false

    // Cooktop-specific
    @State private var cooktopOnsite = false

    private let cutoutTypes: [(String, String)] = [
        ("sink", "Sink"),
        ("cooktop", "Cooktop"),
        ("soap_dispenser", "Soap Dispenser"),
        ("air_gap", "Air Gap"),
        ("outlet_popup", "Outlet/Popup"),
        ("electrical_outlet", "Electrical Outlet"),
        ("other", "Other"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Cutout Type", selection: $cutoutType) {
                        ForEach(cutoutTypes, id: \.0) { value, label in
                            Text(label).tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Details") {
                    TextField("Make", text: $make)
                        .textInputAutocapitalization(.words)
                    TextField("Model", text: $modelText)
                        .textInputAutocapitalization(.words)
                    Stepper("Count: \(count)", value: $count, in: 1...10)
                    TextField("Location Note", text: $locationNote)
                }

                if cutoutType == "sink" {
                    SinkCutoutForm(
                        installType: $sinkInstallType,
                        faucetHoles: $faucetHoles,
                        bringToShop: $bringToShop
                    )
                }

                if cutoutType == "cooktop" {
                    CooktopCutoutForm(onsite: $cooktopOnsite)
                }
            }
            .navigationTitle("Add Cutout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let data = CutoutFormData(
                            cutoutType: cutoutType,
                            make: make.isEmpty ? nil : make,
                            modelName: modelText.isEmpty ? nil : modelText,
                            sinkInstallType: cutoutType == "sink" ? sinkInstallType : nil,
                            faucetHoles: cutoutType == "sink" ? faucetHoles : nil,
                            bringToShop: cutoutType == "sink" ? bringToShop : false,
                            cooktopOnsite: cutoutType == "cooktop" ? cooktopOnsite : nil,
                            count: count,
                            locationNote: locationNote.isEmpty ? nil : locationNote
                        )
                        onAdd(data)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
