import SwiftUI

// MARK: - Status Badge

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Navigate Button

struct NavigateButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Navigate", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                .font(.subheadline)
        }
        .buttonStyle(.bordered)
        .tint(.blue)
    }
}

// MARK: - Offline Banner

struct OfflineBanner: View {
    var body: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .font(.caption)
            Text("Offline — changes will sync when connected")
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(.orange)
        .foregroundStyle(.white)
    }
}

// MARK: - Sync Status Indicator

struct SyncStatusIndicator: View {
    let syncEngine: SyncEngine
    @State private var pendingCount = 0

    var body: some View {
        Group {
            if pendingCount > 0 {
                HStack(spacing: 2) {
                    Circle()
                        .fill(.yellow)
                        .frame(width: 8, height: 8)
                    Text("\(pendingCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
            }
        }
        .task {
            pendingCount = await syncEngine.pendingCount
        }
    }
}
