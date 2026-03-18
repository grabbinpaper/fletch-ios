import SwiftUI

/// Section header for a photo group with count badge and add button.
struct PhotoGroupHeader: View {
    let title: String
    let icon: String
    let count: Int
    let tint: Color
    var onAdd: (() -> Void)? = nil

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .foregroundStyle(tint)

            Text("\(count)")
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(tint.opacity(0.15))
                .foregroundStyle(tint)
                .clipShape(Capsule())

            Spacer()

            if let onAdd {
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(tint)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
