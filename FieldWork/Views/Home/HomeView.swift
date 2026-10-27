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

                    if todayBookings.isEmpty {
                        SFEmptyState(
                            title: "No jobs on today's schedule.",
                            message: "Pull down to check for new bookings."
                        )
                        .padding(.top, 48)
                    }
                }
                .padding()
            }
            .sfScreenBackground()
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.large)
            .sfBrandBar()
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
                    .fill(.sfSuccess)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(.sfSuccess.opacity(0.4), lineWidth: 3)
                            .scaleEffect(1.5)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Active visit")
                        .font(.caption.bold())
                        .foregroundStyle(.sfSuccess)
                    if let name = booking.customerName {
                        Text(name)
                            .font(.subheadline.bold())
                            .foregroundStyle(.sfInk)
                    }
                    Text(booking.visitStatus == "en_route" ? "En route" : "On site")
                        .font(.caption)
                        .foregroundStyle(.sfInkMuted)
                }

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.sfSuccess)
            }
            .padding()
            .background(Color.sfAccentTint)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.sfSuccess.opacity(0.3), lineWidth: 1)
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
                color: .sfInkMuted
            )

            Divider().overlay(Color.sfHairline).frame(height: 50)

            statCell(
                value: "\(completedCount)",
                label: "Done",
                icon: "checkmark.circle.fill",
                color: .sfSuccess
            )

            Divider().overlay(Color.sfHairline).frame(height: 50)

            let sqft = todayBookings.reduce(0.0) { total, booking in
                total + booking.surfaces.reduce(0.0) { $0 + ($1.estimatedSqft ?? 0) }
            }
            statCell(
                value: sqft > 0 ? String(format: "%.0f", sqft) : "—",
                label: "Sq Ft",
                icon: "square.dashed",
                color: .sfInkMuted
            )
        }
        .padding(.vertical, 16)
        .sfCard()
    }

    private func statCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title2, design: .monospaced).bold())
                .foregroundStyle(.sfInk)
            Text(label)
                .font(.caption)
                .foregroundStyle(.sfInkMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Next Up

    private func nextUpCard(_ booking: CachedBooking) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                SFSectionLabel("Next up")
                Spacer()
                Text(booking.startDatetime.formatted(date: .omitted, time: .shortened))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.sfInkMuted)
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
                                .font(.system(.subheadline, design: .monospaced).bold())
                                .foregroundStyle(.sfInk)
                        }
                        if let name = booking.customerName {
                            Text(name)
                                .font(.subheadline)
                                .foregroundStyle(.sfInk)
                        }
                        Spacer()
                        StatusBadge(
                            text: booking.isInstallVisit ? "Install" : "Template",
                            color: booking.isInstallVisit ? .sfInfo : .sfAccentStrong
                        )
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                        Text(booking.fullAddress)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.sfInkMuted)

                    HStack(spacing: 12) {
                        Label("\(booking.surfaceCount) surfaces", systemImage: "square.stack.3d.up")
                            .font(.caption)
                        if booking.priority != "standard" {
                            StatusBadge(text: booking.priority.capitalized, color: .sfWarning)
                        }
                    }
                    .foregroundStyle(.sfInkMuted)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
        .sfCard()
    }

    // MARK: - Remaining

    private var remainingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SFSectionLabel("Later today")
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            ForEach(remainingJobs, id: \.bookingId) { booking in
                NavigationLink(value: booking) {
                    HStack {
                        Text(booking.startDatetime.formatted(date: .omitted, time: .shortened))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.sfInkMuted)
                            .frame(width: 64, alignment: .leading)

                        if let name = booking.customerName {
                            Text(name)
                                .font(.subheadline)
                                .foregroundStyle(.sfInk)
                                .lineLimit(1)
                        }

                        Spacer()

                        StatusBadge(
                            text: booking.isInstallVisit ? "Install" : "Template",
                            color: booking.isInstallVisit ? .sfInfo : .sfAccentStrong
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
        .sfCard()
    }

    // MARK: - Week Ahead

    private var weekAheadSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SFSectionLabel("This week")

            ForEach(upcomingBookings, id: \.bookingId) { booking in
                HStack {
                    Text(booking.scheduledDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.sfInkMuted)
                    if let name = booking.customerName {
                        Text(name)
                            .font(.subheadline)
                            .foregroundStyle(.sfInk)
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .sfCard()
    }
}
