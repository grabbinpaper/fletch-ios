import SwiftUI
import SwiftData

@main
struct FieldWorkApp: App {
    @State private var appState: AppState

    init() {
        // Clerk has to be running before AppState's Supabase client asks it for a token.
        AuthManager.configure()
        _appState = State(initialValue: AppState())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(.sfAccentStrong)
                .environment(appState)
                .modelContainer(appState.modelContainer)
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var brandNamespace
    @State private var launchFinished = false

    var body: some View {
        ZStack {
            if appState.isCheckingAuth || !launchFinished {
                SFLaunchView()
                    .transition(.opacity)
            } else if appState.isAuthenticated {
                MainTabView()
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .environment(\.sfBrandNamespace, brandNamespace)
        .task {
            // Let the launch slide play out even when the session comes back instantly.
            async let minimumLaunch: Void = holdLaunch()
            await appState.checkExistingSession()
            await minimumLaunch
            withAnimation(.smooth(duration: 0.45)) {
                launchFinished = true
            }
        }
    }

    private func holdLaunch() async {
        guard !reduceMotion else { return }
        try? await Task.sleep(for: SFLaunchView.duration)
    }
}
