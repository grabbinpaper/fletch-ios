import SwiftUI

struct SinkCutoutForm: View {
    @Binding var installType: String
    @Binding var faucetHoles: Int
    @Binding var bringToShop: Bool

    private let installTypes: [(String, String)] = [
        ("undermount", "Undermount"),
        ("drop_in", "Drop-in"),
        ("farmhouse", "Farmhouse"),
        ("vessel", "Vessel"),
    ]

    var body: some View {
        Section("Sink Details") {
            Picker("Install Type", selection: $installType) {
                ForEach(installTypes, id: \.0) { value, label in
                    Text(label).tag(value)
                }
            }
            Stepper("Faucet Holes: \(faucetHoles)", value: $faucetHoles, in: 0...6)
            Toggle("Bring to Shop", isOn: $bringToShop)
        }
    }
}
