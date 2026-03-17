import SwiftUI
import SwiftData

struct ScheduleView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ScheduleViewModel()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                scheduleList

                if !appState.networkMonitor.isConnected {
                    OfflineBanner()
                }
            }
            .navigationTitle("Schedule")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(Date.todayFormatted)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        SyncStatusIndicator(syncEngine: appState.syncEngine)

                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.loadSchedule(context: modelContext)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
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
                ProgressView("Loading schedule...")
                Spacer()
            }
        } else if let error = viewModel.error {
            ContentUnavailableView(
                "Error Loading Schedule",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
        } else if viewModel.bookings.isEmpty {
            ContentUnavailableView(
                "No Jobs Today",
                systemImage: "calendar.badge.checkmark",
                description: Text("You have no scheduled jobs for today.")
            )
        } else {
            List {
                if !viewModel.inProgressBookings.isEmpty {
                    Section("In Progress") {
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
            .navigationDestination(for: CachedBooking.self) { booking in
                JobDetailView(booking: booking)
            }
        }
    }
}
