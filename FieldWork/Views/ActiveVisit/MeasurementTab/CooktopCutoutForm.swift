import SwiftUI

struct CooktopCutoutForm: View {
    @Binding var onsite: Bool

    var body: some View {
        Section("Cooktop Details") {
            Toggle("Cooktop On-site", isOn: $onsite)
        }
    }
}
