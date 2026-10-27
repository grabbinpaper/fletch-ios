import SwiftUI
import SwiftData

struct ScheduleView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ScheduleViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                dayPicker
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                ZStack(alignment: .top) {
                    scheduleList

                    if !appState.networkMonitor.isConnected {
                        OfflineBanner()
                    }
                }
            }
            .background(Color.sfSurface100.ignoresSafeArea())
            .navigationTitle("Schedule")
            .sfBrandBar()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SyncStatusIndicator(syncEngine: appState.syncEngine)
                }
            }
            .refreshable {
                await viewModel.loadSchedule(context: modelContext, day: appState.scheduleDay)
            }
            .task(id: appState.scheduleDay) {
                viewModel.configure(appState: appState)
                await viewModel.loadSchedule(context: modelContext, day: appState.scheduleDay)
            }
            .navigationDestination(for: CachedBooking.self) { booking in
                JobDetailView(booking: booking)
            }
        }
    }

    /// Today / Tomorrow, sized for a gloved thumb, with the day's date under it.
    private var dayPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(ScheduleDay.allCases, id: \.self) { day in
                    let selected = appState.scheduleDay == day
                    Button {
                        appState.scheduleDay = day
                    } label: {
                        Text(day.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(selected ? Color.sfSurface200 : Color.sfInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(selected ? Color.sfInk : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(4)
            .background(Color.sfSurface300)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .animation(.easeOut(duration: 0.15), value: appState.scheduleDay)

            Text(appState.scheduleDay.formatted)
                .font(.subheadline)
                .foregroundStyle(Color.sfInkMuted)
        }
    }

    @ViewBuilder
    private var scheduleList: some View {
        if viewModel.isLoading && viewModel.bookings.isEmpty {
            VStack {
                Spacer()
                ProgressView("Loading schedule…")
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else if let error = viewModel.error {
            SFEmptyState(title: "Couldn't load the schedule.", message: error)
                .frame(maxHeight: .infinity)
        } else if viewModel.bookings.isEmpty {
            SFEmptyState(
                title: appState.scheduleDay == .today
                    ? "No jobs on today's schedule."
                    : "Nothing booked for tomorrow yet.",
                message: "Pull down to check for new bookings."
            )
            .frame(maxHeight: .infinity)
        } else {
            List {
                if !viewModel.inProgressBookings.isEmpty {
                    Section("In progress") {
                        ForEach(viewModel.inProgressBookings, id: \.bookingId) { booking in
                            NavigationLink(value: booking) {
                                ScheduleJobRow(booking: booking)
                            }
                        }
                    }
                    .listRowBackground(Color.sfSurface200)
                }

                if !viewModel.upcomingBookings.isEmpty {
                    Section("Upcoming") {
                        ForEach(viewModel.upcomingBookings, id: \.bookingId) { booking in
                            NavigationLink(value: booking) {
                                ScheduleJobRow(booking: booking)
                            }
                        }
                    }
                    .listRowBackground(Color.sfSurface200)
                }

                if !viewModel.completedBookings.isEmpty {
                    Section("Completed") {
                        ForEach(viewModel.completedBookings, id: \.bookingId) { booking in
                            NavigationLink(value: booking) {
                                ScheduleJobRow(booking: booking)
                            }
                        }
                    }
                    .listRowBackground(Color.sfSurface200)
                }
            }
            .listStyle(.insetGrouped)
            .sfScreenBackground()
        }
    }
}
