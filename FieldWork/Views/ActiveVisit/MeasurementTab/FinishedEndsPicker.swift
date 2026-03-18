import SwiftUI

struct FinishedEndsPicker: View {
    @Binding var selection: String
    let isReadOnly: Bool

    private let options = ["none", "left", "right", "both"]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Finished Ends")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if isReadOnly {
                Text(selection.capitalized)
                    .font(.subheadline)
            } else {
                Picker("Finished Ends", selection: $selection) {
                    ForEach(options, id: \.self) { option in
                        Text(option.capitalized).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}
