import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showSignOutConfirm = false
    @AppStorage("defaultStartAddress") private var defaultStartAddress = ""
    @State private var pendingOps = 0
    @State private var failedOps = 0

    var body: some View {
        NavigationStack {
            List {
                // Profile
                Section("Profile") {
                    LabeledContent("Name", value: appState.staffName)
                    if let orgId = appState.organizationId {
                        LabeledContent("Organization", value: orgId.uuidString.prefix(8) + "...")
                    }
                    if let crewId = appState.crewId {
                        LabeledContent("Crew", value: crewId.uuidString.prefix(8) + "...")
                    }
                }

                // Travel
                Section("Default start location") {
                    TextField("Home or shop address", text: $defaultStartAddress, axis: .vertical)
                        .lineLimit(2...4)
                        .textContentType(.fullStreetAddress)
                    if !defaultStartAddress.isEmpty {
                        Text("Pre-filled when starting the first visit of the day.")
                            .font(.caption)
                            .foregroundStyle(.sfInkMuted)
                    }
                }

                // Sync Status
                Section("Sync") {
                    HStack {
                        Text("Connection")
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(appState.networkMonitor.isConnected ? .sfSuccess : .sfDanger)
                                .frame(width: 8, height: 8)
                            Text(appState.networkMonitor.isConnected ? "Online" : "Offline")
                                .font(.subheadline)
                                .foregroundStyle(.sfInkMuted)
                        }
                    }

                    LabeledContent("Waiting to sync", value: "\(pendingOps)")
                    LabeledContent("Failed to sync", value: "\(failedOps)")

                    if pendingOps > 0 {
                        Button("Retry sync") {
                            Task {
                                await appState.syncEngine.processPendingOperations()
                                await loadSyncCounts()
                            }
                        }
                    }
                }

                // Sign Out
                Section {
                    Button(role: .destructive) {
                        if pendingOps > 0 {
                            showSignOutConfirm = true
                        } else {
                            signOut()
                        }
                    } label: {
                        Text("Sign out")
                    }
                } footer: {
                    VStack(spacing: 8) {
                        SFLogoLockup(markSize: 18)
                        Text("FieldWork \(appVersion)")
                            .font(.caption)
                            .foregroundStyle(Color.sfInkMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                }
            }
            .sfScreenBackground()
            .navigationTitle("Settings")
            .sfBrandBar()
            .alert("Unsynced changes", isPresented: $showSignOutConfirm) {
                Button("Sign out anyway", role: .destructive) { signOut() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("\(pendingOps) changes haven't synced yet. Signing out may lose them.")
            }
            .task {
                await loadSyncCounts()
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    private func signOut() {
        Task {
            await appState.signOut()
            dismiss()
        }
    }

    private func loadSyncCounts() async {
        pendingOps = await appState.syncEngine.pendingCount
        failedOps = await appState.syncEngine.failedCount
    }
}
