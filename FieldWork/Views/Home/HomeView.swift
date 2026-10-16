import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var todayBookings: [CachedBooking] = []
    @State private var upcomingBookings: [CachedBooking] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Active visit banner
                    if let active = activeVisit {
                        activeVisitBanner(active)
                    }

                    // Today's stats
                    todayStats

                    // Next up
                    if let next = nextJob {
                        nextUpCard(next)
                    }

                    // Remaining today
                    if !remainingJobs.isEmpty {
                        remainingSection
                    }

                    // Week ahead
                    if !upcomingBookings.isEmpty {
                        weekAheadSection
                    }
                }
                .padding()
            }
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.large)
            .task {
                loadBookings()
            }
            .refreshable {
                loadBookings()
            }
            .navigationDestination(for: CachedBooking.self) { booking in
                JobDetailView(booking: booking)
            }
        }
    }

    // MARK: - Data

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = appState.staffName.isEmpty ? "" : ", \(appState.staffName)"
        if hour < 12 { return "Morning\(name)" }
        if hour < 17 { return "Afternoon\(name)" }
        return "Evening\(name)"
    }

    private var activeVisit: CachedBooking? {
        todayBookings.first { $0.visitStatus == "en_route" || $0.visitStatus == "on_site" }
    }

    private var nextJob: CachedBooking? {
        todayBookings.first {
            $0.visitStatus == nil && $0.status != "completed" && $0.status != "cancelled"
        }
    }

    private var remainingJobs: [CachedBooking] {
        todayBookings.filter {
            $0.visitStatus == nil && $0.status != "completed" && $0.status != "cancelled"
            && $0.bookingId != nextJob?.bookingId
        }
    }

    private var completedCount: Int {
        todayBookings.filter { $0.visitStatus == "completed" || $0.status == "completed" }.count
    }

    private var totalToday: Int {
        todayBookings.count
    }

    private func loadBookings() {
        todayBookings = (try? modelContext.fetch(ScheduleViewModel.todaysBookingsDescriptor())) ?? []
        // The phone only downloads today's schedule, so there's nothing upcoming to show yet.
        upcomingBookings = []
    }

    // MARK: - Active Visit Banner

    private func activeVisitBanner(_ booking: CachedBooking) -> some View {
        Button {
            appState.activeBooking = booking
            appState.selectedTab = .activeVisit
        } label: {
            HStack(spacing: 12) {
                // Pulsing indicator
                Circle()
                    .fill(.green)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(.green.opacity(0.4), lineWidth: 3)
                            .scaleEffect(1.5)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Active Visit")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                    if let name = booking.customerName {
                        Text(name)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                    }
                    Text(booking.visitStatus == "en_route" ? "En route" : "On site")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Today Stats

    private var todayStats: some View {
        HStack(spacing: 0) {
            statCell(
                value: "\(totalToday)",
                label: "Visits",
                icon: "calendar",
                color: .blue
            )

            Divider().frame(height: 50)

            statCell(
                value: "\(completedCount)",
                label: "Done",
                icon: "checkmark.circle.fill",
                color: .green
            )

            Divider().frame(height: 50)

            let sqft = todayBookings.reduce(0.0) { total, booking in
                total + booking.surfaces.reduce(0.0) { $0 + ($1.estimatedSqft ?? 0) }
            }
            statCell(
                value: sqft > 0 ? String(format: "%.0f", sqft) : "—",
                label: "Sq Ft",
                icon: "square.dashed",
                color: .purple
            )
        }
        .padding(.vertical, 16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold().monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Next Up

    private func nextUpCard(_ booking: CachedBooking) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("NEXT UP")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(booking.startDatetime.formatted(date: .omitted, time: .shortened))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Job info
            NavigationLink(value: booking) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        if let number = booking.jobNumber {
                            Text("#\(number)")
                                .font(.subheadline.bold())
                        }
                        if let name = booking.customerName {
                            Text(name)
                                .font(.subheadline)
                        }
                        Spacer()
                        StatusBadge(
                            text: booking.isInstallVisit ? "Install" : "Template",
                            color: booking.isInstallVisit ? .purple : .blue
                        )
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                        Text(booking.fullAddress)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Label("\(booking.surfaceCount) surfaces", systemImage: "square.stack.3d.up")
                            .font(.caption)
                        if booking.priority != "standard" {
                            StatusBadge(text: booking.priority.capitalized, color: .orange)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Remaining

    private var remainingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("LATER TODAY")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            ForEach(remainingJobs, id: \.bookingId) { booking in
                NavigationLink(value: booking) {
                    HStack {
                        Text(booking.startDatetime.formatted(date: .omitted, time: .shortened))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 55, alignment: .leading)

                        if let name = booking.customerName {
                            Text(name)
                                .font(.subheadline)
                                .lineLimit(1)
                        }

                        Spacer()

                        StatusBadge(
                            text: booking.isInstallVisit ? "Install" : "Template",
                            color: booking.isInstallVisit ? .purple : .blue
                        )
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                if booking.bookingId != remainingJobs.last?.bookingId {
                    Divider().padding(.leading)
                }
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Week Ahead

    private var weekAheadSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THIS WEEK")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(upcomingBookings, id: \.bookingId) { booking in
                HStack {
                    Text(booking.scheduledDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let name = booking.customerName {
                        Text(name)
                            .font(.subheadline)
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
