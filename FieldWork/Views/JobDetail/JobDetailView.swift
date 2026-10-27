import SwiftUI
import SwiftData

struct JobDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: JobDetailViewModel
    @State private var showBlockedSheet = false

    init(booking: CachedBooking) {
        _viewModel = State(initialValue: JobDetailViewModel(booking: booking))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    jobHeader
                    warningCards
                    customerCard
                    siteCard
                    surfacesSection
                    travelCard
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }

            // Sticky bottom CTA
            bottomCTA
        }
        .navigationTitle(viewModel.booking.jobNumber.map { "#\($0)" } ?? "Job Detail")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.configure(appState: appState)
            appState.locationManager.requestPermission()
        }
        .sheet(isPresented: $showBlockedSheet) {
            BlockedVisitSheet { reason, notes in
                Task {
                    await viewModel.reportBlocked(reason: reason, notes: notes, context: modelContext)
                    showBlockedSheet = false
                }
            }
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    // MARK: - Job Header

    private var jobHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if viewModel.booking.priority != "standard" {
                        StatusBadge(text: viewModel.booking.priority.capitalized,
                                    color: .sfWarning)
                    }
                    if let type = viewModel.booking.constructionType {
                        Text(type.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(viewModel.booking.serviceName)
                    .font(.subheadline.bold())
                Text(viewModel.booking.startDatetime.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Warnings

    @ViewBuilder
    private var warningCards: some View {
        if viewModel.booking.tearoutRequired || viewModel.booking.plumbingDisconnect {
            VStack(spacing: 6) {
                if viewModel.booking.tearoutRequired {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.sfWarning)
                            .font(.caption)
                        Text("Tearout Required")
                            .font(.caption.bold())
                        Spacer()
                    }
                }
                if viewModel.booking.plumbingDisconnect {
                    HStack(spacing: 8) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundStyle(.sfAccentStrong)
                            .font(.caption)
                        Text("Plumbing Disconnect")
                            .font(.caption.bold())
                        Spacer()
                    }
                }
                if let notes = viewModel.booking.specialInstructions {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(10)
            .background(Color.sfWarning.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Customer Card

    private var customerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Customer name + phone
            HStack {
                if let name = viewModel.booking.customerName {
                    Text(name)
                        .font(.headline)
                }
                Spacer()
                if let phone = viewModel.booking.customerPhone {
                    Button { viewModel.callPhone(phone) } label: {
                        Image(systemName: "phone.fill")
                            .font(.subheadline)
                            .foregroundStyle(.sfAccentStrong)
                    }
                }
            }

            // Salesperson inline
            if let salesperson = viewModel.booking.salespersonName {
                HStack(spacing: 4) {
                    Text("Sales:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(salesperson)
                        .font(.caption)
                    if let phone = viewModel.booking.salespersonPhone {
                        Button { viewModel.callPhone(phone) } label: {
                            Image(systemName: "phone.fill")
                                .font(.caption2)
                                .foregroundStyle(.sfAccentStrong)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Site Card

    private var siteCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(viewModel.booking.fullAddress)
                    .font(.subheadline)
                Spacer()
                Button { viewModel.openInMaps() } label: {
                    Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.sfAccentStrong)
                }
            }

            if let contactName = viewModel.booking.contactName ?? viewModel.booking.siteContactName {
                HStack(spacing: 4) {
                    Text("Contact:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(contactName)
                        .font(.caption)
                    if let phone = viewModel.booking.contactPhone ?? viewModel.booking.siteContactPhone {
                        Button { viewModel.callPhone(phone) } label: {
                            Image(systemName: "phone.fill")
                                .font(.caption2)
                                .foregroundStyle(.sfAccentStrong)
                        }
                    }
                }
            }

            if let access = viewModel.booking.siteAccessNotes {
                Text(access)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Scope

    private var surfacesSection: some View {
        HStack(spacing: 16) {
            let rooms = viewModel.booking.roomCount
            let surfaces = viewModel.booking.surfaceCount

            Label(rooms == 1 ? "1 room" : "\(rooms) rooms",
                  systemImage: "door.left.hand.open")
                .font(.subheadline)

            Label(surfaces == 1 ? "1 surface" : "\(surfaces) surfaces",
                  systemImage: "rectangle.3.group")
                .font(.subheadline)

            Spacer()

            if viewModel.booking.templatedSurfaceCount > 0 {
                Text("\(viewModel.booking.templatedSurfaceCount)/\(viewModel.booking.surfaceCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.sfSuccess)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Travel Card

    @ViewBuilder
    private var travelCard: some View {
        if let miles = viewModel.booking.travelMiles,
           let minutes = viewModel.booking.travelTimeMinutes {
            HStack(spacing: 16) {
                Label(String(format: "%.1f mi", miles), systemImage: "road.lanes")
                    .font(.caption)
                Label("\(minutes) min", systemImage: "clock")
                    .font(.caption)
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Sticky Bottom CTA

    private var bottomCTA: some View {
        VStack(spacing: 8) {
            if appState.locationManager.isDenied {
                locationRequiredCard
            } else if !appState.locationManager.isAuthorized {
                // Still .notDetermined — request on appear
                locationRequestCard
            } else {
                visitActions
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var locationRequiredCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "location.slash.fill")
                    .foregroundStyle(.sfDanger)
                Text("Location access is required to start visits")
                    .font(.subheadline)
            }
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var locationRequestCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .foregroundStyle(.sfAccentStrong)
                Text("Location needed to track mileage and verify on-site work")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                appState.locationManager.requestPermission()
            } label: {
                Text("Enable Location")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var visitActions: some View {
        Group {
            switch viewModel.visitState {
            case .notStarted:
                // One tap — captures GPS silently, marks en_route
                Button {
                    Task {
                        await viewModel.startVisit(startingAddress: nil, context: modelContext)
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isStartingVisit {
                            ProgressView().tint(.sfOnFill)
                        } else {
                            Image(systemName: "car.fill")
                        }
                        Text("Heading Out")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isStartingVisit)

                cantMakeItButton

            case .enRoute:
                // One tap — captures arrival GPS, marks on_site
                Button {
                    Task {
                        await viewModel.arriveAtSite(context: modelContext)
                        openActiveVisit()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isArrivingAtSite {
                            ProgressView().tint(.sfOnFill)
                        } else {
                            Image(systemName: "mappin.and.ellipse")
                        }
                        Text("I'm Here")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.sfSuccess)
                .disabled(viewModel.isArrivingAtSite)

                cantMakeItButton

            case .onSite:
                Button { openActiveVisit() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Continue Visit")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)

            case .completed:
                Button { openActiveVisit() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.fill")
                        Text("View Summary")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.bordered)

            case .blocked:
                HStack(spacing: 10) {
                    Image(systemName: "nosign")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Couldn't make this visit")
                            .font(.subheadline.bold())
                        Text("Reported to the office.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    /// Second, quieter action under Heading Out / I'm Here: report the visit can't happen.
    private var cantMakeItButton: some View {
        Button { showBlockedSheet = true } label: {
            Label("Can't Make It", systemImage: "nosign")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(.bordered)
        .tint(.primary)
    }

    private func openActiveVisit() {
        appState.activeBooking = viewModel.booking
        appState.selectedTab = .activeVisit
    }
}
