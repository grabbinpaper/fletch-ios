import SwiftUI
import SwiftData

struct InstallSignTabView: View {
    @Bindable var viewModel: ActiveInstallViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var clearSignal = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Completion summary
                summaryCard

                // Signature section
                if viewModel.booking.signatureCaptured {
                    signatureCapturedCard
                } else if viewModel.signatureMode == .inPerson {
                    inPersonSignatureCard
                } else {
                    remoteSignatureCard
                }
            }
            .padding()
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Installation Summary", systemImage: "checklist")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                summaryItem(
                    count: viewModel.installedCount,
                    total: viewModel.totalSurfaceCount,
                    label: "installed",
                    color: .green
                )

                if viewModel.flaggedCount > 0 {
                    summaryItem(
                        count: viewModel.flaggedCount,
                        total: viewModel.totalSurfaceCount,
                        label: "flagged",
                        color: .orange
                    )
                }
            }

            // Flagged surfaces list
            let flagged = viewModel.booking.surfaces.filter { surface in
                let status = viewModel.status(for: surface.surfaceId)
                return status?.status == "partial" || status?.status == "not_installed"
            }
            if !flagged.isEmpty {
                Divider()
                ForEach(flagged, id: \.surfaceId) { surface in
                    let status = viewModel.status(for: surface.surfaceId)
                    HStack {
                        Text(surface.displayName)
                            .font(.subheadline)
                        Spacer()
                        if status?.status == "partial" {
                            StatusBadge(text: "Partial", color: .orange)
                        } else {
                            StatusBadge(text: "Not Installed", color: .red)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func summaryItem(count: Int, total: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)/\(total)")
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Signature Captured

    private var signatureCapturedCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Signature Captured")
                .font(.headline)

            if !viewModel.signatureName.isEmpty {
                Text("Signed by: \(viewModel.signatureName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let img = viewModel.signatureImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 120)
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Start over button
            Button {
                viewModel.clearSignature(context: modelContext)
                clearSignal += 1
            } label: {
                Label("Start Over", systemImage: "arrow.counterclockwise")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - In-Person Signature

    private var inPersonSignatureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Customer Signature", systemImage: "pencil.and.scribble")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            Text("Hand device to customer to sign below")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Signature pad
            SignaturePadView(clearSignal: $clearSignal) { image in
                viewModel.signatureImage = image
            }
            .frame(height: 200)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )

            // Clear + name row
            HStack {
                Button {
                    clearSignal += 1
                    viewModel.signatureImage = nil
                } label: {
                    Label("Clear", systemImage: "arrow.counterclockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Spacer()
            }

            // Customer name
            TextField("Customer name", text: $viewModel.signatureName)
                .textFieldStyle(.roundedBorder)

            // Save the signature (the visit is finished with the button at the bottom)
            Button {
                if let image = viewModel.signatureImage {
                    viewModel.saveSignature(
                        image: image,
                        signerName: viewModel.signatureName.trimmingCharacters(in: .whitespaces),
                        context: modelContext
                    )
                }
            } label: {
                Label("Save Signature", systemImage: "checkmark.seal")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(viewModel.signatureImage == nil
                      || viewModel.signatureName.trimmingCharacters(in: .whitespaces).isEmpty)

            // Switch to remote
            Button {
                viewModel.signatureMode = .remote
            } label: {
                Text("Send signature link instead")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Remote Signature

    private var remoteSignatureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Remote Signature", systemImage: "paperplane")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            if let email = viewModel.booking.customerEmail {
                Label(email, systemImage: "envelope")
                    .font(.subheadline)
            }

            if let phone = viewModel.booking.customerPhone {
                Label(phone, systemImage: "phone")
                    .font(.subheadline)
            }

            Picker("Send by", selection: $viewModel.remoteChannel) {
                Text("Text").tag(SignoffChannel.sms)
                    .disabled(viewModel.booking.customerPhone?.isEmpty ?? true)
                Text("Email").tag(SignoffChannel.email)
                    .disabled(viewModel.booking.customerEmail?.isEmpty ?? true)
            }
            .pickerStyle(.segmented)

            if viewModel.booking.visitStatus != "completed" {
                Text("The link goes to the customer when you finish the visit (button at the bottom).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                if viewModel.signatureLinkSent {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading) {
                            Text("Sign-off link sent")
                                .font(.subheadline.bold())
                            if let sentAt = viewModel.signatureLinkSentAt {
                                Text(sentAt.formatted(date: .omitted, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Button {
                    Task { await viewModel.sendSignoffLink() }
                } label: {
                    Label(viewModel.signatureLinkSent ? "Re-send Link" : "Send Sign-off Link",
                          systemImage: "paperplane.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSendingLink)

                if let err = viewModel.signoffError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            // Switch to in-person
            Button {
                viewModel.signatureMode = .inPerson
            } label: {
                Text("Capture signature in person instead")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
