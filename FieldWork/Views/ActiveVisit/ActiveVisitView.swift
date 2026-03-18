import SwiftUI
import SwiftData

struct ActiveVisitView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: ActiveVisitViewModel
    @State private var showCameraFromSurface = false

    init(booking: CachedBooking) {
        _viewModel = State(initialValue: ActiveVisitViewModel(booking: booking))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Tab", selection: $viewModel.selectedTab) {
                ForEach(visibleTabs, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Tab content
            TabView(selection: $viewModel.selectedTab) {
                MeasurementTabView(
                    viewModel: viewModel,
                    onCameraForSurface: { surfaceId in
                        viewModel.pendingSurfaceId = surfaceId
                        showCameraFromSurface = true
                    }
                )
                .tag(VisitTab.measurements)

                SiteConditionTabView(viewModel: viewModel)
                    .tag(VisitTab.site)

                PhotoTabView(viewModel: viewModel)
                    .tag(VisitTab.photos)

                ChecklistTabView(viewModel: viewModel)
                    .tag(VisitTab.checklist)

                if viewModel.requiresSignature || viewModel.signaturePending || viewModel.booking.signatureCaptured {
                    SignatureTabView(viewModel: viewModel)
                        .tag(VisitTab.signature)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Bottom bar
            if viewModel.booking.visitStatus != "completed" {
                bottomBar
            }
        }
        .navigationTitle("Template Visit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }

            ToolbarItem(placement: .topBarTrailing) {
                draftSaveIndicator
            }
        }
        .task {
            viewModel.configure(appState: appState)
            viewModel.loadChecklist(context: modelContext)
            viewModel.loadPhotos(context: modelContext)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                viewModel.saveDraftNow(context: modelContext)
            }
        }
        .sheet(isPresented: $viewModel.showCompletionSheet) {
            CompletionView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showPartialSheet) {
            PartialVisitSheet(viewModel: viewModel)
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
                    .foregroundStyle(.green)
                Text("Saved")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .error(let msg):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text(msg)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        case .idle:
            EmptyView()
        }
    }

    private var visibleTabs: [VisitTab] {
        var tabs: [VisitTab] = [.measurements, .site, .photos, .checklist]
        if viewModel.requiresSignature || viewModel.signaturePending || viewModel.booking.signatureCaptured {
            tabs.append(.signature)
        }
        return tabs
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            // Progress summary
            HStack {
                ProgressView(value: viewModel.measurementProgress)
                    .tint(viewModel.measurementProgress == 1.0 ? .green : .blue)
                HStack(spacing: 4) {
                    Text("\(viewModel.measuredCount)/\(viewModel.totalMeasurementCount) measured")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if viewModel.skippedCount > 0 {
                        Text("\u{00B7} \(viewModel.skippedCount) skipped")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(.horizontal)

            Button {
                viewModel.initiateCompletion()
            } label: {
                if viewModel.isValidating {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Checking requirements...")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                } else if viewModel.isAllMeasured {
                    Text("Complete Visit")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                } else {
                    Text("Complete as Partial (\(viewModel.measuredCount)/\(viewModel.totalMeasurementCount))")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isAllMeasured ? .green : .orange)
            .disabled(!viewModel.canComplete)
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(.bar)
    }
}
