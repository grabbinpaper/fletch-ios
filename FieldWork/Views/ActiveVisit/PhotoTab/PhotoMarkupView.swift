import SwiftUI
import PencilKit

struct PhotoMarkupView: View {
    let image: UIImage
    let onSave: (UIImage, Data?) -> Void  // base image + PKDrawing data (compositing done by caller)
    let onSkip: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var canvasView = PKCanvasView()
    @State private var selectedColorIndex = 0
    @State private var toolType: ToolType = .pen

    enum ToolType {
        case pen, marker
    }

    private struct ColorOption: Identifiable {
        let id: Int
        let label: String
        let swatchColor: Color
        let inkColor: UIColor
    }

    private let colors: [ColorOption] = [
        ColorOption(id: 0, label: "Red", swatchColor: .red, inkColor: .systemRed),
        ColorOption(id: 1, label: "Yellow", swatchColor: .yellow, inkColor: .systemYellow),
        ColorOption(id: 2, label: "White", swatchColor: .white, inkColor: .white),
        ColorOption(id: 3, label: "Cyan", swatchColor: .cyan, inkColor: .cyan),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                GeometryReader { geo in
                    let imageSize = fitSize(for: image.size, in: geo.size)

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
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            onSkip()
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveAndDismiss()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .green)
                    }
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
        HStack(spacing: 12) {
            // Color picker
            ForEach(colors) { option in
                Button {
                    selectedColorIndex = option.id
                    updateTool()
                } label: {
                    Circle()
                        .fill(option.swatchColor)
                        .frame(width: 32, height: 32)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    selectedColorIndex == option.id ? Color.white : Color.gray.opacity(0.5),
                                    lineWidth: selectedColorIndex == option.id ? 3 : 1
                                )
                        }
                }
            }

            Divider()
                .frame(height: 28)

            // Tool picker
            Button {
                toolType = .pen
                updateTool()
            } label: {
                Image(systemName: "pencil.tip")
                    .font(.title3)
                    .foregroundStyle(toolType == .pen ? .white : .gray)
            }
            .frame(width: 36, height: 36)

            Button {
                toolType = .marker
                updateTool()
            } label: {
                Image(systemName: "highlighter")
                    .font(.title3)
                    .foregroundStyle(toolType == .marker ? .white : .gray)
            }
            .frame(width: 36, height: 36)

            Divider()
                .frame(height: 28)

            // Undo
            Button {
                canvasView.undoManager?.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.title3)
            }
            .frame(width: 36, height: 36)

            // Clear
            Button {
                canvasView.drawing = PKDrawing()
            } label: {
                Image(systemName: "trash")
                    .font(.title3)
            }
            .frame(width: 36, height: 36)
        }
    }

    private func configureCanvas() {
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        updateTool()
    }

    private func updateTool() {
        let uiColor = colors[selectedColorIndex].inkColor
        switch toolType {
        case .pen:
            canvasView.tool = PKInkingTool(.pen, color: uiColor, width: 5)
        case .marker:
            canvasView.tool = PKInkingTool(.marker, color: uiColor.withAlphaComponent(0.5), width: 20)
        }
    }

    private func saveAndDismiss() {
        let drawing = canvasView.drawing
        let hasDrawing = !drawing.strokes.isEmpty

        // Capture drawing data and canvas info NOW, before dismiss tears down the view
        var drawingData: Data?
        var compositedImage = image

        if hasDrawing {
            drawingData = drawing.dataRepresentation()
            let canvasSize = canvasView.bounds.size
            if canvasSize.width > 0, canvasSize.height > 0 {
                let imageSize = image.size
                let scaleX = imageSize.width / canvasSize.width
                let scaleY = imageSize.height / canvasSize.height
                let drawingImage = drawing.image(
                    from: CGRect(origin: .zero, size: canvasSize),
                    scale: max(scaleX, scaleY)
                )
                let renderer = UIGraphicsImageRenderer(size: imageSize)
                compositedImage = renderer.image { _ in
                    image.draw(at: .zero)
                    drawingImage.draw(in: CGRect(origin: .zero, size: imageSize))
                }
            }
        }

        // Dismiss first, then deliver result after the sheet is gone
        dismiss()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            onSave(compositedImage, drawingData)
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
