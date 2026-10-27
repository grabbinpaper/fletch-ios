import SwiftUI
import SwiftData

struct ScheduleView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ScheduleViewModel()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                scheduleList

                if !appState.networkMonitor.isConnected {
                    OfflineBanner()
                }
            }
            .background(Color.sfSurface100.ignoresSafeArea())
            .navigationTitle("Schedule")
            .sfBrandBar()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(Date.todayFormatted)
                        .font(.subheadline)
                        .foregroundStyle(.sfInkMuted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    SyncStatusIndicator(syncEngine: appState.syncEngine)
                }
            }
            .refreshable {
                await viewModel.loadSchedule(context: modelContext)
            }
            .task {
                viewModel.configure(appState: appState)
                await viewModel.loadSchedule(context: modelContext)
            }
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
                title: "No jobs on today's schedule.",
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
                }

                if !viewModel.upcomingBookings.isEmpty {
                    Section("Upcoming") {
                        ForEach(viewModel.upcomingBookings, id: \.bookingId) { booking in
                            NavigationLink(value: booking) {
                                ScheduleJobRow(booking: booking)
                            }
                        }
                    }
                }

                if !viewModel.completedBookings.isEmpty {
                    Section("Completed") {
                        ForEach(viewModel.completedBookings, id: \.bookingId) { booking in
                            NavigationLink(value: booking) {
                                ScheduleJobRow(booking: booking)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listRowBackground(Color.sfSurface200)
            .sfScreenBackground()
            .navigationDestination(for: CachedBooking.self) { booking in
                JobDetailView(booking: booking)
            }
        }
    }
}
