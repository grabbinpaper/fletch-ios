import SwiftUI
import PencilKit

struct PhotoMarkupView: View {
    let image: UIImage
    let onSave: (UIImage, Data?) -> Void  // composited image + PKDrawing data
    let onSkip: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var canvasView = PKCanvasView()
    @State private var selectedColor: Color = .red
    @State private var toolType: ToolType = .pen

    enum ToolType {
        case pen, marker
    }

    private let colors: [(Color, UIColor)] = [
        (.red, .systemRed),
        (.blue, .systemBlue),
        (.black, .black),
        (.white, .white)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                GeometryReader { geo in
                    let imageSize = fitSize(for: image.size, in: geo.size)
                    let offset = CGPoint(
                        x: (geo.size.width - imageSize.width) / 2,
                        y: (geo.size.height - imageSize.height) / 2
                    )

                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: imageSize.width, height: imageSize.height)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)

                        CanvasRepresentable(canvasView: $canvasView)
                            .frame(width: imageSize.width, height: imageSize.height)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                }
            }
            .navigationTitle("Mark Up Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip") {
                        onSkip()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        saveAndDismiss()
                    }
                    .bold()
                }

                ToolbarItemGroup(placement: .bottomBar) {
                    toolBar
                }
            }
            .onAppear {
                configureCanvas()
            }
        }
    }

    private var toolBar: some View {
        HStack(spacing: 16) {
            // Color picker
            ForEach(colors, id: \.1) { color, _ in
                Button {
                    selectedColor = color
                    updateTool()
                } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 28, height: 28)
                        .overlay {
                            if selectedColor == color {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 2.5)
                                    .frame(width: 34, height: 34)
                            }
                        }
                }
            }

            Divider()
                .frame(height: 24)

            // Tool picker
            Button {
                toolType = .pen
                updateTool()
            } label: {
                Image(systemName: "pencil.tip")
                    .foregroundStyle(toolType == .pen ? .white : .gray)
            }

            Button {
                toolType = .marker
                updateTool()
            } label: {
                Image(systemName: "highlighter")
                    .foregroundStyle(toolType == .marker ? .white : .gray)
            }

            Divider()
                .frame(height: 24)

            // Undo
            Button {
                canvasView.undoManager?.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }

            // Clear
            Button {
                canvasView.drawing = PKDrawing()
            } label: {
                Image(systemName: "trash")
            }
        }
    }

    private func configureCanvas() {
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        updateTool()
    }

    private func updateTool() {
        let uiColor = colors.first { $0.0 == selectedColor }?.1 ?? .systemRed
        switch toolType {
        case .pen:
            canvasView.tool = PKInkingTool(.pen, color: uiColor, width: 4)
        case .marker:
            canvasView.tool = PKInkingTool(.marker, color: uiColor.withAlphaComponent(0.5), width: 15)
        }
    }

    private func saveAndDismiss() {
        let drawing = canvasView.drawing
        let hasDrawing = !drawing.strokes.isEmpty

        if hasDrawing {
            // Composite the drawing over the image at image resolution
            let compositedImage = renderComposite()
            onSave(compositedImage, drawing.dataRepresentation())
        } else {
            onSave(image, nil)
        }
        dismiss()
    }

    private func renderComposite() -> UIImage {
        let imageSize = image.size
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        return renderer.image { context in
            image.draw(at: .zero)

            // Scale the canvas drawing to match the original image dimensions
            let canvasSize = canvasView.bounds.size
            guard canvasSize.width > 0, canvasSize.height > 0 else { return }

            let scaleX = imageSize.width / canvasSize.width
            let scaleY = imageSize.height / canvasSize.height

            let drawingImage = canvasView.drawing.image(
                from: canvasView.bounds,
                scale: max(scaleX, scaleY)
            )
            drawingImage.draw(in: CGRect(origin: .zero, size: imageSize))
        }
    }

    private func fitSize(for imageSize: CGSize, in containerSize: CGSize) -> CGSize {
        let widthRatio = containerSize.width / imageSize.width
        let heightRatio = containerSize.height / imageSize.height
        let scale = min(widthRatio, heightRatio)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }
}

// MARK: - Canvas UIViewRepresentable

private struct CanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
