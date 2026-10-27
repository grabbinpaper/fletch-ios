import SwiftUI
import SwiftData

struct ActiveInstallView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: ActiveInstallViewModel
    @State private var showCameraFromSurface = false

    init(booking: CachedBooking) {
        _viewModel = State(initialValue: ActiveInstallViewModel(booking: booking))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Tab", selection: $viewModel.selectedTab) {
                ForEach(viewModel.visibleTabs, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Tab content
            TabView(selection: $viewModel.selectedTab) {
                AreasTabView(
                    viewModel: viewModel,
                    onCameraForSurface: { surfaceId in
                        viewModel.pendingSurfaceId = surfaceId
                        showCameraFromSurface = true
                    }
                )
                .tag(InstallTab.areas)

                InstallSiteTabView(viewModel: viewModel)
                    .tag(InstallTab.site)

                InstallPhotoTabView(viewModel: viewModel)
                    .tag(InstallTab.photos)

                InstallChecklistTabView(viewModel: viewModel)
                    .tag(InstallTab.checklist)

                if viewModel.visibleTabs.contains(.sign) {
                    InstallSignTabView(viewModel: viewModel)
                        .tag(InstallTab.sign)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Bottom bar
            if viewModel.booking.visitStatus != "completed" {
                bottomBar
            }
        }
        .onChange(of: viewModel.visibleTabs) { _, tabs in
            if !tabs.contains(viewModel.selectedTab) { viewModel.selectedTab = .areas }
        }
        .navigationTitle("Install Visit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Schedule") {
                    appState.selectedTab = .schedule
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                draftSaveIndicator
            }
        }
        .task {
            viewModel.configure(appState: appState)
            viewModel.initializeSurfaceStatuses(context: modelContext)
            viewModel.loadPhotos(context: modelContext)
            viewModel.loadChecklist(context: modelContext)
            await viewModel.loadIssueReasons()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                viewModel.saveDraftNow(context: modelContext)
            }
        }
        .sheet(isPresented: $viewModel.showCompletionSheet) {
            InstallCompletionView(viewModel: viewModel)
        }
        .sheet(isPresented: $showCameraFromSurface) {
            CameraView { image in
                viewModel.capturePhoto(
                    image: image,
                    surfaceId: viewModel.pendingSurfaceId,
                    context: modelContext
                )
            }
        }
        .sheet(isPresented: $viewModel.showMarkup, onDismiss: {
            viewModel.pendingImage = nil
        }) {
            if let image = viewModel.pendingImage {
                PhotoMarkupView(
                    image: image,
                    onSave: { compositedImage, drawingData in
                        if viewModel.isSiteCapture {
                            viewModel.deferSitePhoto(image: compositedImage, annotationData: drawingData)
                        } else {
                            viewModel.savePhoto(
                                image: compositedImage,
                                annotationData: drawingData,
                                surfaceId: viewModel.pendingSurfaceId,
                                caption: viewModel.pendingCaption,
                                category: viewModel.pendingCategory,
                                context: modelContext
                            )
                        }
                    },
                    onSkip: {
                        if viewModel.isSiteCapture {
                            viewModel.deferSitePhoto(image: image, annotationData: nil)
                        } else {
                            viewModel.savePhoto(
                                image: image,
                                annotationData: nil,
                                surfaceId: viewModel.pendingSurfaceId,
                                caption: viewModel.pendingCaption,
                                category: viewModel.pendingCategory,
                                context: modelContext
                            )
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $viewModel.showSiteTagPicker) {
            SiteTagPickerSheet(
                selectedTags: $viewModel.selectedSiteTags,
                note: $viewModel.sitePhotoNote,
                onSave: {
                    viewModel.showSiteTagPicker = false
                    viewModel.savePendingSitePhoto(context: modelContext)
                },
                onCancel: {
                    viewModel.showSiteTagPicker = false
                    viewModel.savePendingSitePhoto(context: modelContext)
                }
            )
        }
    }

    // MARK: - Draft Save Indicator

    @ViewBuilder
    private var draftSaveIndicator: some View {
        switch viewModel.draftManager.state {
        case .saving:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                Text("Saving...")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .saved:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.sfSuccess)
                Text("Saved")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .error(let msg):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.sfWarning)
                Text(msg)
                    .font(.caption2)
                    .foregroundStyle(.sfWarning)
            }
        case .idle:
            EmptyView()
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            // Progress summary
            HStack {
                ProgressView(value: viewModel.surfaceProgress)
                    .tint(viewModel.allInstalled ? .sfSuccess : .sfAccentStrong)
                HStack(spacing: 4) {
                    Text("\(viewModel.confirmedCount)/\(viewModel.totalSurfaceCount) confirmed")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if viewModel.flaggedCount > 0 {
                        Text("\u{00B7} \(viewModel.flaggedCount) flagged")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.sfWarning)
                    }
                }
            }
            .padding(.horizontal)

            Button {
                viewModel.showCompletionSheet = true
            } label: {
                Text(viewModel.ctaLabel)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.ctaColor)
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(.bar)
    }
}
