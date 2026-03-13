import SwiftUI
import SwiftData

@main
struct FieldWorkApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .modelContainer(appState.modelContainer)
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.isCheckingAuth {
                ProgressView("Loading...")
            } else if appState.isAuthenticated {
                ScheduleView()
            } else {
                LoginView()
            }
        }
        .task {
            await appState.checkExistingSession()
        }
    }
}
