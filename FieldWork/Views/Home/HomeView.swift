import SwiftUI
import SwiftData

/// Today, and only today: the job to do now as a big card with one clear button,
/// then the rest of the day as cards large enough to hit with a gloved thumb.
struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var todayBookings: [CachedBooking] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if todayBookings.isEmpty {
                        SFEmptyState(
                            title: "No jobs on today's schedule.",
                            message: "Pull down to check for new bookings."
                        )
                        .padding(.top, 48)
                    } else if isDayDone {
                        dayDoneCard

                        SFSectionLabel("Today")
                            .padding(.top, 12)
                        ForEach(otherJobs, id: \.bookingId) { booking in
                            jobCard(booking)
                        }
                    } else {
                        summaryCard

                        if let hero = heroJob {
                            heroCard(hero)
                        }

                        if !otherJobs.isEmpty {
                            SFSectionLabel(heroJob == nil ? "Today" : "Rest of today")
                                .padding(.top, 12)
                            ForEach(otherJobs, id: \.bookingId) { booking in
                                jobCard(booking)
                            }
                        }
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

    private var isDayDone: Bool {
        !todayBookings.isEmpty && todayBookings.allSatisfy { isDone($0) || $0.status == "cancelled" }
    }

    private var totalSqft: Double {
        todayBookings.reduce(0) { total, booking in
            total + booking.surfaces.reduce(0) { $0 + ($1.estimatedSqft ?? 0) }
        }
    }

    /// "5 jobs · 4 templates · 1 install · 277 sq ft"
    private var dayMix: String {
        let installs = todayBookings.filter(\.isInstallVisit).count
        let templates = todayBookings.count - installs
        var parts = [plural(todayBookings.count, "job")]
        if templates > 0 { parts.append(plural(templates, "template")) }
        if installs > 0 { parts.append(plural(installs, "install")) }
        if totalSqft > 0 { parts.append("\(Int(totalSqft.rounded())) sq ft") }
        return parts.joined(separator: " · ")
    }

    /// "7:30 AM – 5:00 PM"
    private var daySpan: String? {
        guard let first = todayBookings.map(\.startDatetime).min(),
              let last = todayBookings.map(\.endDatetime).max() else { return nil }
        let start = first.formatted(date: .omitted, time: .shortened)
        let end = last.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }

    private func plural(_ count: Int, _ word: String) -> String {
        "\(count) \(word)\(count == 1 ? "" : "s")"
    }

    private var activeVisit: CachedBooking? {
        todayBookings.first { isUnderway($0) }
    }

    private var nextJob: CachedBooking? {
        todayBookings.first { isWaiting($0) }
    }

    /// The one job to act on now: the visit underway, else the next one waiting.
    private var heroJob: CachedBooking? {
        activeVisit ?? nextJob
    }

    /// Everything else today in time order, with finished jobs moved to the end.
    private var otherJobs: [CachedBooking] {
        let rest = todayBookings.filter { $0.bookingId != heroJob?.bookingId && $0.status != "cancelled" }
        return rest.filter { !isDone($0) } + rest.filter { isDone($0) }
    }

    private var completedCount: Int {
        todayBookings.filter { isDone($0) }.count
    }

    private func isUnderway(_ booking: CachedBooking) -> Bool {
        booking.visitStatus == "en_route" || booking.visitStatus == "on_site"
    }

    private func isDone(_ booking: CachedBooking) -> Bool {
        booking.visitStatus == "completed" || booking.status == "completed"
    }

    private func isWaiting(_ booking: CachedBooking) -> Bool {
        booking.visitStatus == nil && booking.status != "completed" && booking.status != "cancelled"
    }

    private func loadBookings() {
        todayBookings = (try? modelContext.fetch(ScheduleViewModel.todaysBookingsDescriptor())) ?? []
    }

    // MARK: - Day summary

    /// The whole day at a glance: date, hours, the mix of work, and how far along it is.
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(Date.todayFormatted)
                    .font(.headline)
                    .foregroundStyle(Color.sfInk)
                Spacer()
                if let daySpan {
                    Text(daySpan)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Color.sfInkMuted)
                }
            }

            Text(dayMix)
                .font(.subheadline)
                .foregroundStyle(Color.sfInkMuted)

            VStack(alignment: .leading, spacing: 6) {
                ProgressBar(fraction: Double(completedCount) / Double(max(todayBookings.count, 1)))
                Text("\(completedCount) of \(todayBookings.count) done")
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color.sfInkMuted)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .sfCard()
    }

    /// Everything's finished: say so, total it up, and point at tomorrow.
    private var dayDoneCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.sfSuccess)
                Text("Day done")
                    .font(.title2.bold())
                    .foregroundStyle(Color.sfInk)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(completedCount) of \(todayBookings.count) jobs finished")
                    .font(.body)
                    .foregroundStyle(Color.sfInk)
                Text(dayMix)
                    .font(.subheadline)
                    .foregroundStyle(Color.sfInkMuted)
            }

            Button {
                appState.scheduleDay = .tomorrow
                appState.selectedTab = .schedule
            } label: {
                heroButtonLabel("See tomorrow")
            }
            .buttonStyle(SFPrimaryButtonStyle())
        }
        .padding(20)
        .sfCard()
    }

    // MARK: - Hero

    private func heroCard(_ booking: CachedBooking) -> some View {
        let underway = isUnderway(booking)
        let isFirst = completedCount == 0 && !underway

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                if underway {
                    Circle()
                        .fill(Color.sfAccent)
                        .frame(width: 8, height: 8)
                    Text(booking.visitStatus == "en_route" ? "Heading there" : "On site")
                        .foregroundStyle(Color.sfAccentStrong)
                } else {
                    Text(isFirst ? "First up" : "Next up")
                        .foregroundStyle(Color.sfInkMuted)
                }
                Spacer()
                Text(booking.startDatetime.formatted(date: .omitted, time: .shortened))
                    .monospacedDigit()
                    .foregroundStyle(Color.sfInkMuted)
            }
            .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text(booking.customerName ?? booking.jobNumber ?? "Job")
                    .font(.title2.bold())
                    .foregroundStyle(Color.sfInk)
                if !booking.fullAddress.isEmpty {
                    Text(booking.fullAddress)
                        .font(.body)
                        .foregroundStyle(Color.sfInkMuted)
                }
                jobTags(booking)
                    .padding(.top, 4)
            }

            if underway {
                Button {
                    appState.activeBooking = booking
                    appState.selectedTab = .activeVisit
                } label: {
                    heroButtonLabel("Continue visit")
                }
                .buttonStyle(SFPrimaryButtonStyle())
            } else {
                NavigationLink(value: booking) {
                    heroButtonLabel("Open job")
                }
                .buttonStyle(SFPrimaryButtonStyle())
            }
        }
        .padding(20)
        .sfCard()
    }

    private func heroButtonLabel(_ title: String) -> some View {
        HStack {
            Text(title)
            Image(systemName: "arrow.right")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
    }

    // MARK: - Rest of today

    private func jobCard(_ booking: CachedBooking) -> some View {
        let done = isDone(booking)

        return NavigationLink(value: booking) {
            HStack(alignment: .center, spacing: 16) {
                Text(booking.startDatetime.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color.sfInkMuted)
                    .frame(width: 72, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.customerName ?? booking.jobNumber ?? "Job")
                        .font(.headline)
                        .foregroundStyle(done ? Color.sfInkMuted : Color.sfInk)
                        .lineLimit(1)
                    if done {
                        Label("Done", systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.sfSuccess)
                    } else {
                        jobTags(booking)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.sfInkMuted)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 76)
            .contentShape(Rectangle())
            .sfCard()
        }
        .buttonStyle(.plain)
    }

    /// Visit type, surface count, and priority when it isn't standard.
    private func jobTags(_ booking: CachedBooking) -> some View {
        HStack(spacing: 8) {
            StatusBadge(text: booking.isInstallVisit ? "Install" : "Template", color: .sfInkMuted)
            if booking.priority != "standard" {
                StatusBadge(
                    text: booking.priority.capitalized,
                    color: booking.priority == "rush" ? .sfWarning : .sfDanger
                )
            }
            Text(booking.surfaceCount == 1 ? "1 surface" : "\(booking.surfaceCount) surfaces")
                .font(.subheadline)
                .foregroundStyle(Color.sfInkMuted)
        }
    }
}

/// Brand progress bar: ink on a surface-300 track.
private struct ProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.sfSurface300)
                Capsule()
                    .fill(Color.sfInk)
                    .frame(width: geo.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 6)
        .accessibilityElement()
        .accessibilityValue("\(Int((fraction * 100).rounded())) percent")
    }
}
