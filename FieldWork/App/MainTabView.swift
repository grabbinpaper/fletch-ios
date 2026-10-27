import SwiftUI
import SwiftData

enum AppTab: String {
    case home
    case schedule
    case activeVisit
    case settings
}

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        @Bindable var appState = appState

        // Teal marks only the selected tab; inside each tab, buttons and links are charcoal.
        TabView(selection: $appState.selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                HomeView()
                    .tint(.sfInk)
            }

            Tab("Schedule", systemImage: "calendar", value: AppTab.schedule) {
                ScheduleView()
                    .tint(.sfInk)
            }

            Tab("Visit", systemImage: activeVisitIcon, value: AppTab.activeVisit) {
                activeVisitContent
                    .tint(.sfInk)
            }
            .badge(appState.activeBooking != nil ? 1 : 0)

            Tab("Settings", systemImage: "gear", value: AppTab.settings) {
                SettingsView()
                    .tint(.sfInk)
            }
        }
    }

    private var activeVisitIcon: String {
        appState.activeBooking != nil ? "wrench.and.screwdriver.fill" : "wrench.and.screwdriver"
    }

    @ViewBuilder
    private var activeVisitContent: some View {
        if let booking = appState.activeBooking {
            NavigationStack {
                if booking.isInstallVisit {
                    ActiveInstallView(booking: booking)
                } else {
                    ActiveVisitView(booking: booking)
                }
            }
        } else {
            NavigationStack {
                SFEmptyState(
                    title: "No visit in progress",
                    message: "Start a visit from the schedule to begin working."
                )
                .frame(maxHeight: .infinity)
                .background(Color.sfSurface100.ignoresSafeArea())
                .navigationTitle("Visit")
                .sfBrandBar()
            }
        }
    }
}
