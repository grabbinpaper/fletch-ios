import SwiftUI
import SwiftData

struct InstallSignTabView: View {
    @Bindable var viewModel: ActiveInstallViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var clearSignal = 0
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var editingPhone = false
    @State private var editingEmail = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Completion summary
                summaryCard

                // Signature section
                if viewModel.booking.signatureCaptured {
                    signatureCapturedCard
                } else {
                    signoffChoices
                    if viewModel.signatureMode == .inPerson {
                        inPersonSignatureCard
                    } else {
                        remoteSignatureCard
                    }
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
        .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - Sign-off Choices

    /// Two big choices: send the customer a link (the usual way), or sign on this device.
    private var signoffChoices: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How will the customer sign off?")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                choiceButton(
                    mode: .remote,
                    title: "Text / Email Link",
                    subtitle: "Customer signs on their own phone",
                    systemImage: "paperplane.fill"
                )

                choiceButton(
                    mode: .inPerson,
                    title: "Sign on This Device",
                    subtitle: "Hand the device over",
                    systemImage: "hand.draw.fill"
                )
            }
        }
    }

    private func choiceButton(mode: SignatureMode, title: String, subtitle: String, systemImage: String) -> some View {
        let selected = viewModel.signatureMode == mode
        return Button {
            viewModel.signatureMode = mode
        } label: {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title2)
                Text(title)
                    .font(.subheadline.bold())
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(selected ? Color.white.opacity(0.85) : .secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding(.horizontal, 8)
            .foregroundStyle(selected ? Color.white : Color.accentColor)
            .background(selected ? Color.accentColor : Color.accentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor.opacity(selected ? 0 : 0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
            .frame(height: sizeClass == .regular ? 360 : 200)
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
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Remote Signature

    private var remoteSignatureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Sign-off Link", systemImage: "paperplane")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            Text("Send by text, email, or both")
                .font(.caption)
                .foregroundStyle(.secondary)

            linkChannelRow(
                isOn: $viewModel.sendByText,
                title: "Text",
                systemImage: "message.fill",
                address: $viewModel.linkPhone,
                onFile: viewModel.booking.customerPhone,
                placeholder: "Phone number",
                keyboard: .phonePad,
                isEditing: $editingPhone
            )

            Divider()

            linkChannelRow(
                isOn: $viewModel.sendByEmail,
                title: "Email",
                systemImage: "envelope.fill",
                address: $viewModel.linkEmail,
                onFile: viewModel.booking.customerEmail,
                placeholder: "Email address",
                keyboard: .emailAddress,
                isEditing: $editingEmail
            )

            if viewModel.linkTargets.isEmpty {
                Label("Pick text or email so the link has somewhere to go", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

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
                .disabled(viewModel.isSendingLink || viewModel.linkTargets.isEmpty)

                if let err = viewModel.signoffError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// One way to send the link: tick it on, see where it goes (from the office's records), and
    /// change the address for this send if the customer asks for somewhere else.
    private func linkChannelRow(
        isOn: Binding<Bool>, title: String, systemImage: String, address: Binding<String>,
        onFile: String?, placeholder: String, keyboard: UIKeyboardType, isEditing: Binding<Bool>
    ) -> some View {
        let onFileValue = onFile ?? ""
        let showField = isEditing.wrappedValue || onFileValue.isEmpty
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                isOn.wrappedValue.toggle()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                        .font(.title2)
                        .foregroundStyle(isOn.wrappedValue ? Color.accentColor : .secondary)
                    Label(title, systemImage: systemImage)
                        .font(.headline)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOn.wrappedValue {
                if showField {
                    TextField(placeholder, text: address)
                        .keyboardType(keyboard)
                        .textContentType(keyboard == .phonePad ? .telephoneNumber : .emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                    Text("A number or email that isn't on file goes on the customer's record for the office to confirm.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    if !onFileValue.isEmpty {
                        Button("Use the one on file: \(onFileValue)") {
                            address.wrappedValue = onFileValue
                            isEditing.wrappedValue = false
                        }
                        .font(.caption)
                    } else {
                        Text("Nothing on file — type where the customer wants it")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        Text(address.wrappedValue)
                            .font(.subheadline)
                        Spacer()
                        Button("Send somewhere else") { isEditing.wrappedValue = true }
                            .font(.caption)
                    }
                    .padding(.leading, 40)
                }
            }
        }
    }
}
