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

        TabView(selection: $appState.selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                HomeView()
            }

            Tab("Schedule", systemImage: "calendar", value: AppTab.schedule) {
                ScheduleView()
            }

            Tab("Visit", systemImage: activeVisitIcon, value: AppTab.activeVisit) {
                activeVisitContent
            }
            .badge(appState.activeBooking != nil ? 1 : 0)

            Tab("Settings", systemImage: "gear", value: AppTab.settings) {
                SettingsView()
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
