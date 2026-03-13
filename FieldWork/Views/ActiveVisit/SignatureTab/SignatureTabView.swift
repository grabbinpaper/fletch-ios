import SwiftUI
import SwiftData

struct SignatureTabView: View {
    @Bindable var viewModel: ActiveVisitViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var signerName = ""
    @State private var lines: [[CGPoint]] = []
    @State private var currentLine: [CGPoint] = []

    var body: some View {
        VStack(spacing: 16) {
            if viewModel.booking.signatureCaptured {
                ContentUnavailableView(
                    "Signature Captured",
                    systemImage: "checkmark.seal.fill",
                    description: Text("Signature has been saved.")
                )
            } else {
                Text("Customer Signature")
                    .font(.headline)

                // Signer name
                TextField("Signer Name", text: $signerName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                // Signature canvas
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
                        )

                    Canvas { context, _ in
                        for line in lines {
                            var path = Path()
                            guard let first = line.first else { continue }
                            path.move(to: first)
                            for point in line.dropFirst() {
                                path.addLine(to: point)
                            }
                            context.stroke(path, with: .color(.black), lineWidth: 2)
                        }

                        // Current line
                        if !currentLine.isEmpty {
                            var path = Path()
                            path.move(to: currentLine[0])
                            for point in currentLine.dropFirst() {
                                path.addLine(to: point)
                            }
                            context.stroke(path, with: .color(.black), lineWidth: 2)
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                currentLine.append(value.location)
                            }
                            .onEnded { _ in
                                lines.append(currentLine)
                                currentLine = []
                            }
                    )

                    if lines.isEmpty && currentLine.isEmpty {
                        Text("Sign here")
                            .foregroundStyle(.secondary)
                            .allowsHitTesting(false)
                    }
                }
                .frame(height: 200)
                .padding(.horizontal)

                HStack {
                    Button("Clear") {
                        lines = []
                        currentLine = []
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Save Signature") {
                        saveSignature()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(lines.isEmpty || signerName.isEmpty)
                }
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding(.top)
    }

    private func saveSignature() {
        // Render canvas to UIImage
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 300))
        let image = renderer.image { ctx in
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.fill(CGRect(x: 0, y: 0, width: 600, height: 300))

            ctx.cgContext.setStrokeColor(UIColor.black.cgColor)
            ctx.cgContext.setLineWidth(2)
            ctx.cgContext.setLineCap(.round)

            for line in lines {
                guard let first = line.first else { continue }
                ctx.cgContext.move(to: first)
                for point in line.dropFirst() {
                    ctx.cgContext.addLine(to: point)
                }
                ctx.cgContext.strokePath()
            }
        }

        viewModel.saveSignature(image: image, signerName: signerName, context: modelContext)
    }
}
