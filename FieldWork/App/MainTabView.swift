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
                NavigationStack {
                    SettingsView()
                }
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
            ContentUnavailableView(
                "No Active Visit",
                systemImage: "wrench.and.screwdriver",
                description: Text("Start a visit from the schedule to begin working.")
            )
        }
    }
}
