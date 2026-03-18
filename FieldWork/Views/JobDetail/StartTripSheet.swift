import SwiftUI
import SwiftData

struct StartTripSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let booking: CachedBooking
    let onStart: (String?) -> Void

    @State private var startingAddress: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        if let customer = booking.customerName {
                            Text(customer)
                                .font(.headline)
                        }
                        Text(booking.fullAddress)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let salesperson = booking.salespersonName {
                            HStack(spacing: 4) {
                                Label(salesperson, systemImage: "briefcase.fill")
                                    .font(.caption)
                                if let spPhone = booking.salespersonPhone {
                                    Text("·")
                                    Text(spPhone)
                                        .font(.caption)
                                }
                            }
                            .foregroundStyle(.secondary)
                        }
                        if let contact = booking.contactName ?? booking.siteContactName {
                            HStack(spacing: 4) {
                                Label(contact, systemImage: "person.fill")
                                    .font(.caption)
                                if let phone = booking.contactPhone ?? booking.siteContactPhone {
                                    Text("·")
                                    Text(phone)
                                        .font(.caption)
                                }
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Starting From") {
                    TextField("Enter address...", text: $startingAddress, axis: .vertical)
                        .lineLimit(2...4)
                        .textContentType(.fullStreetAddress)
                }

                Section {
                    Button {
                        onStart(startingAddress.isEmpty ? nil : startingAddress)
                    } label: {
                        HStack {
                            Spacer()
                            Label("Start Visit", systemImage: "car.fill")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.accentColor)
                    .foregroundStyle(.white)
                }
            }
            .navigationTitle("Start Visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                startingAddress = resolveDefaultAddress()
            }
        }
        .presentationDetents([.medium])
    }

    private func resolveDefaultAddress() -> String {
        // Check if another visit was completed today — use that job's site address
        if let previousAddress = lastCompletedJobAddress() {
            return previousAddress
        }
        // Fall back to user's default start location
        return UserDefaults.standard.string(forKey: "defaultStartAddress") ?? ""
    }

    private func lastCompletedJobAddress() -> String? {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let currentBookingId = booking.bookingId
        var descriptor = FetchDescriptor<CachedBooking>(
            predicate: #Predicate<CachedBooking> {
                $0.visitStatus == "completed"
                && $0.scheduledDate >= startOfDay
                && $0.bookingId != currentBookingId
            },
            sortBy: [SortDescriptor(\.visitCompletedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        guard let results = try? modelContext.fetch(descriptor),
              let lastBooking = results.first else {
            return nil
        }
        let address = lastBooking.fullAddress
        return address.isEmpty ? nil : address
    }
}
