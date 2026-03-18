import SwiftUI
import SwiftData

struct SignatureTabView: View {
    @Bindable var viewModel: ActiveVisitViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if viewModel.booking.signatureCaptured {
                // Already signed (via remote link)
                ContentUnavailableView(
                    "Signature Received",
                    systemImage: "checkmark.seal.fill",
                    description: Text("The customer has signed via the approval link.")
                )
            } else if viewModel.signaturePending {
                // Visit completed, signature link sent
                VStack(spacing: 16) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)

                    Text("Signature Link Sent")
                        .font(.title3.bold())

                    Text("The customer will receive a link to review the visit summary and sign. You're all set — no action needed here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            } else if viewModel.requiresSignature {
                // Before completion — signature required but will be async
                VStack(spacing: 16) {
                    Image(systemName: "signature")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue.opacity(0.7))

                    Text("Signature Required")
                        .font(.title3.bold())

                    Text("After you complete this visit, the customer will receive a text or email with a link to review and sign. No on-device signature needed.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    if let name = viewModel.booking.customerName, !name.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.secondary)
                            Text(name)
                                .font(.subheadline.bold())
                        }
                        .padding(.top, 8)
                    }
                }
            } else {
                // No signature required for this customer
                ContentUnavailableView(
                    "No Signature Required",
                    systemImage: "signature",
                    description: Text("This customer does not require a signature.")
                )
            }

            Spacer()
        }
        .padding(.top)
    }
}
