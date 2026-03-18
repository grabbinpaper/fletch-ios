import SwiftUI

struct ScheduleJobRow: View {
    let booking: CachedBooking

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Time
                Text(booking.startDatetime.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)

                Spacer()

                // Priority badge
                if booking.priority != "standard" {
                    StatusBadge(
                        text: booking.priority.capitalized,
                        color: priorityColor
                    )
                }

                // Visit status
                if let visitStatus = booking.visitStatus {
                    StatusBadge(
                        text: visitStatusLabel(visitStatus),
                        color: visitStatusColor(visitStatus)
                    )
                }
            }

            // Job number + customer
            HStack {
                if let jobNumber = booking.jobNumber {
                    Text("#\(jobNumber)")
                        .font(.headline)
                }

                if let name = booking.customerName {
                    Text(name)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }

            // Address
            if !booking.fullAddress.isEmpty {
                Text(booking.fullAddress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Surface count
            HStack(spacing: 4) {
                Image(systemName: "square.dashed")
                    .font(.caption2)
                Text("\(booking.templatedSurfaceCount)/\(booking.surfaceCount) surfaces")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var priorityColor: Color {
        switch booking.priority {
        case "rush": return .orange
        case "remake", "warranty": return .red
        case "emergency": return .red
        default: return .gray
        }
    }

    private func visitStatusLabel(_ status: String) -> String {
        switch status {
        case "en_route": return "En Route"
        case "on_site": return "On Site"
        case "completed": return "Done"
        case "blocked": return "Blocked"
        default: return status.capitalized
        }
    }

    private func visitStatusColor(_ status: String) -> Color {
        switch status {
        case "en_route": return .blue
        case "on_site": return .orange
        case "completed": return .green
        case "blocked": return .red
        default: return .gray
        }
    }
}
