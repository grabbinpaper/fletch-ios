import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showSignOutConfirm = false
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

                // Sync Status
                Section("Sync") {
                    HStack {
                        Text("Connection")
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(appState.networkMonitor.isConnected ? .green : .red)
                                .frame(width: 8, height: 8)
                            Text(appState.networkMonitor.isConnected ? "Online" : "Offline")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    LabeledContent("Pending Operations", value: "\(pendingOps)")
                    LabeledContent("Failed Operations", value: "\(failedOps)")

                    if pendingOps > 0 {
                        Button("Retry Sync") {
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
                        Text("Sign Out")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Pending Sync", isPresented: $showSignOutConfirm) {
                Button("Sign Out Anyway", role: .destructive) { signOut() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You have \(pendingOps) pending operations that haven't synced. Signing out may lose this data.")
            }
            .task {
                await loadSyncCounts()
            }
        }
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
