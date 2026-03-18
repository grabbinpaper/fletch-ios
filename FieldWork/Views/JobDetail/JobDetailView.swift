import SwiftUI
import SwiftData

struct JobDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: JobDetailViewModel
    @State private var showActiveVisit = false
    @State private var showBlockedSheet = false

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

                // Customer card
                customerCard

                // Site card
                siteCard

                // Surfaces
                surfacesSection

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

            if let account = viewModel.booking.accountNumber {
                Text("Account: \(account)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

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

            if let contactName = viewModel.booking.contactName {
                Divider()
                Text("Site Contact: \(contactName)")
                    .font(.subheadline)
                if let phone = viewModel.booking.contactPhone {
                    Button { viewModel.callPhone(phone) } label: {
                        Label(phone, systemImage: "phone.fill")
                            .font(.caption)
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
        VStack(alignment: .leading, spacing: 8) {
            Label("Job Site", systemImage: "mappin.and.ellipse")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            Text(viewModel.booking.fullAddress)
                .font(.subheadline)

            if viewModel.booking.siteLatitude != nil {
                NavigateButton { viewModel.openInMaps() }
            }

            if let contact = viewModel.booking.siteContactName {
                Divider()
                Text("Site Contact: \(contact)")
                    .font(.subheadline)
                if let phone = viewModel.booking.siteContactPhone {
                    Button { viewModel.callPhone(phone) } label: {
                        Label(phone, systemImage: "phone.fill")
                            .font(.caption)
                    }
                }
            }

            if let access = viewModel.booking.siteAccessNotes {
                Divider()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Access Notes")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(access)
                        .font(.caption)
                }
            }

            if let instructions = viewModel.booking.specialInstructions {
                Divider()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Special Instructions")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(instructions)
                        .font(.caption)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Surfaces

    private var surfacesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Surfaces (\(viewModel.booking.surfaceCount))", systemImage: "square.dashed")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            ForEach(viewModel.booking.surfaces, id: \.surfaceId) { surface in
                SurfaceRow(surface: surface)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                    Text("Can't complete this visit")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
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
            Task { await viewModel.startVisit(context: modelContext) }
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

// MARK: - Surface Row

struct SurfaceRow: View {
    let surface: CachedSurface

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(surface.displayName)
                    .font(.subheadline.bold())
                Spacer()
                if surface.isTemplated {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }

            HStack(spacing: 16) {
                if let material = surface.materialName {
                    Label(material, systemImage: "cube.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let edge = surface.edgeProfileName {
                    Label(edge, systemImage: "line.diagonal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                // Estimated
                if let l = surface.estimatedLengthInches, let w = surface.estimatedWidthInches {
                    Text("Est: \(formatInches(l)) x \(formatInches(w))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Actual
                if let l = surface.actualLengthInches, let w = surface.actualWidthInches {
                    Text("Actual: \(formatInches(l)) x \(formatInches(w))")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            }

            if surface.hasBacksplash && !surface.backsplashPieces.isEmpty {
                Text("\(surface.backsplashPieces.count) backsplash piece(s)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatInches(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))\""
        }
        return String(format: "%.1f\"", value)
    }
}
