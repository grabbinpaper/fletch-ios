import SwiftUI

struct ScheduleJobRow: View {
    let booking: CachedBooking

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Time
                Text(booking.startDatetime.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.sfInkMuted)

                Spacer()

                // Priority badge
                if booking.priority != "standard" {
                    StatusBadge(
                        text: booking.priority.capitalized,
                        color: priorityColor
                    )
                }

                // Visit type
                StatusBadge(
                    text: booking.isInstallVisit ? "Install" : "Template",
                    color: .sfInkMuted
                )

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
                    Text(jobNumber)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.sfInk)
                }

                if let name = booking.customerName {
                    Text(name)
                        .font(.subheadline)
                        .foregroundStyle(.sfInk)
                        .lineLimit(1)
                }
            }

            // Address
            if !booking.fullAddress.isEmpty {
                Text(booking.fullAddress)
                    .font(.caption)
                    .foregroundStyle(.sfInkMuted)
                    .lineLimit(1)
            }

            // Salesperson + surface count
            HStack(spacing: 12) {
                if let salesperson = booking.salespersonName {
                    HStack(spacing: 3) {
                        Text("Sales:")
                            .font(.caption)
                        Text(salesperson)
                            .font(.caption)
                    }
                }

                Label(booking.surfaceCount == 1 ? "1 surface" : "\(booking.surfaceCount) surfaces",
                      systemImage: "square.dashed")
                    .font(.caption)
            }
            .foregroundStyle(.sfInkMuted)
        }
        .padding(.vertical, 4)
    }

    private var priorityColor: Color {
        switch booking.priority {
        case "rush": return .sfWarning
        case "remake", "warranty": return .sfDanger
        case "emergency": return .sfDanger
        default: return .sfInkMuted
        }
    }

    private func visitStatusLabel(_ status: String) -> String {
        switch status {
        case "en_route": return "En route"
        case "on_site": return "On site"
        case "completed": return "Done"
        case "blocked": return "Blocked"
        default: return status.capitalized
        }
    }

    private func visitStatusColor(_ status: String) -> Color {
        switch status {
        case "en_route": return .sfAccentStrong
        case "on_site": return .sfWarning
        case "completed": return .sfSuccess
        case "blocked": return .sfDanger
        default: return .sfInkMuted
        }
    }
}
