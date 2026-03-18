import SwiftUI

/// A tappable chip that shows photo requirement status for a checklist item.
/// Shows count of photos taken, with amber warning if required but 0 taken.
struct ChecklistPhotoChip: View {
    let photoCount: Int
    let isRequired: Bool
    let onTap: () -> Void

    private var needsPhoto: Bool {
        isRequired && photoCount == 0
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: photoCount > 0 ? "camera.fill" : "camera")
                    .font(.caption2)
                Text(photoCount > 0 ? "\(photoCount)" : "Photo")
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(chipBackground)
            .foregroundStyle(chipForeground)
            .clipShape(Capsule())
        }
    }

    private var chipBackground: Color {
        if photoCount > 0 {
            return .green.opacity(0.15)
        } else if isRequired {
            return .orange.opacity(0.15)
        }
        return .secondary.opacity(0.1)
    }

    private var chipForeground: Color {
        if photoCount > 0 {
            return .green
        } else if isRequired {
            return .orange
        }
        return .secondary
    }
}
