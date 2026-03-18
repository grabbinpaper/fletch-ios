import SwiftUI
import SwiftData

struct JobDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: JobDetailViewModel
    @State private var showActiveVisit = false
    @State private var showBlockedSheet = false
    @State private var showStartTripSheet = false

    init(booking: CachedBooking) {
        _viewModel = State(initialValue: JobDetailViewModel(booking: booking))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Job header
                jobHeader

                // Warnings
                warningCards

                // Salesperson card
                salespersonCard

                // Customer card
                customerCard

                // Site card
                siteCard

                // Surfaces
                surfacesSection

                // Travel summary
                travelCard

                // CTA
                ctaButton
            }
            .padding()
        }
        .navigationTitle(viewModel.booking.jobNumber.map { "#\($0)" } ?? "Job Detail")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.configure(appState: appState)
            appState.locationManager.requestPermission()
        }
        .fullScreenCover(isPresented: $showActiveVisit) {
            NavigationStack {
                ActiveVisitView(booking: viewModel.booking)
            }
        }
        .sheet(isPresented: $showStartTripSheet) {
            StartTripSheet(booking: viewModel.booking) { address in
                showStartTripSheet = false
                Task {
                    await viewModel.startVisit(startingAddress: address, context: modelContext)
                }
            }
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
                    if let status = viewModel.booking.jobStatus {
                        StatusBadge(text: status.replacingOccurrences(of: "_", with: " ").capitalized,
                                    color: .blue)
                    }
                    if viewModel.booking.priority != "standard" {
                        StatusBadge(text: viewModel.booking.priority.capitalized,
                                    color: .orange)
                    }
                }

                if let type = viewModel.booking.constructionType {
                    Text(type.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        if viewModel.booking.tearoutRequired {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading) {
                    Text("Tearout Required")
                        .font(.subheadline.bold())
                    if let notes = viewModel.booking.specialInstructions {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        if viewModel.booking.plumbingDisconnect {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundStyle(.blue)
                Text("Plumbing disconnect required")
                    .font(.subheadline.bold())
                Spacer()
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Customer Card

    private var customerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Customer", systemImage: "person.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            if let name = viewModel.booking.customerName {
                Text(name)
                    .font(.headline)
            }

            if let phone = viewModel.booking.customerPhone {
                Button { viewModel.callPhone(phone) } label: {
                    Label(phone, systemImage: "phone.fill")
                        .font(.subheadline)
                }
            }

            if let email = viewModel.booking.customerEmail {
                Label(email, systemImage: "envelope.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Salesperson Card

    @ViewBuilder
    private var salespersonCard: some View {
        if let salesperson = viewModel.booking.salespersonName {
            VStack(alignment: .leading, spacing: 8) {
                Label("Salesperson", systemImage: "briefcase.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                Text(salesperson)
                    .font(.headline)

                if let phone = viewModel.booking.salespersonPhone {
                    Button { viewModel.callPhone(phone) } label: {
                        Label(phone, systemImage: "phone.fill")
                            .font(.subheadline)
                    }
                }

                if let email = viewModel.booking.salespersonEmail {
                    Label(email, systemImage: "envelope.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Site Card

    private var siteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Job Site", systemImage: "mappin.and.ellipse")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            Text(viewModel.booking.fullAddress)
                .font(.subheadline)

            if viewModel.booking.siteLatitude != nil {
                NavigateButton { viewModel.openInMaps() }
            }

            if let contactName = viewModel.booking.contactName ?? viewModel.booking.siteContactName {
                Divider()
                Text("Site Contact: \(contactName)")
                    .font(.subheadline)
                if let phone = viewModel.booking.contactPhone ?? viewModel.booking.siteContactPhone {
                    Button { viewModel.callPhone(phone) } label: {
                        Label(phone, systemImage: "phone.fill")
                            .font(.caption)
                    }
                }
            }

            if let access = viewModel.booking.siteAccessNotes {
                Divider()
                Text(access)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let instructions = viewModel.booking.specialInstructions {
                Divider()
                Text(instructions)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Scope Summary

    private var surfacesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Scope", systemImage: "square.dashed")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                let rooms = viewModel.booking.roomCount
                let surfaces = viewModel.booking.surfaceCount

                Label(rooms == 1 ? "1 room" : "\(rooms) rooms",
                      systemImage: "door.left.hand.open")
                    .font(.subheadline)

                Label(surfaces == 1 ? "1 surface" : "\(surfaces) surfaces",
                      systemImage: "rectangle.3.group")
                    .font(.subheadline)
            }

            if viewModel.booking.templatedSurfaceCount > 0 {
                Text("\(viewModel.booking.templatedSurfaceCount) of \(viewModel.booking.surfaceCount) templated")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Travel Card

    @ViewBuilder
    private var travelCard: some View {
        let state = viewModel.visitState
        if state == .enRoute || state == .onSite || state == .completed,
           let address = viewModel.booking.startingAddress, !address.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Travel", systemImage: "car.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(address)
                        .font(.subheadline)
                }

                if let miles = viewModel.booking.travelMiles,
                   let minutes = viewModel.booking.travelTimeMinutes {
                    Divider()
                    HStack(spacing: 16) {
                        Label(String(format: "%.1f mi", miles), systemImage: "road.lanes")
                            .font(.subheadline)
                        Label("\(minutes) min", systemImage: "clock")
                            .font(.subheadline)
                    }
                } else if state == .enRoute {
                    Text("Distance calculated on arrival")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - CTA

    private var ctaButton: some View {
        VStack(spacing: 12) {
            if viewModel.visitState != .blocked {
                Button {
                    handleCTA()
                } label: {
                    HStack {
                        if viewModel.isStartingVisit || viewModel.isArrivingAtSite {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(viewModel.ctaTitle)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isStartingVisit || viewModel.isArrivingAtSite)
            }

            if viewModel.canReportBlocked {
                Button {
                    showBlockedSheet = true
                } label: {
                    Label("Can't complete this visit", systemImage: "xmark.circle.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }

            if viewModel.visitState == .blocked {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("This visit was reported as blocked")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func handleCTA() {
        switch viewModel.visitState {
        case .notStarted:
            showStartTripSheet = true
        case .enRoute:
            Task { await viewModel.arriveAtSite(context: modelContext) }
        case .onSite:
            showActiveVisit = true
        case .completed:
            showActiveVisit = true
        case .blocked:
            break
        }
    }
}

