import SwiftUI
import PencilKit

struct SignaturePadView: UIViewRepresentable {
    @Binding var clearSignal: Int
    var onSignatureChanged: ((UIImage?) -> Void)?

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .black, width: 3)
        canvas.backgroundColor = .white
        canvas.delegate = context.coordinator
        canvas.isOpaque = true
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if context.coordinator.lastClearSignal != clearSignal {
            context.coordinator.lastClearSignal = clearSignal
            uiView.drawing = PKDrawing()
            onSignatureChanged?(nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSignatureChanged: onSignatureChanged)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        let onSignatureChanged: ((UIImage?) -> Void)?
        var lastClearSignal = 0

        init(onSignatureChanged: ((UIImage?) -> Void)?) {
            self.onSignatureChanged = onSignatureChanged
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            if canvasView.drawing.bounds.isEmpty {
                onSignatureChanged?(nil)
            } else {
                let scale = canvasView.window?.windowScene?.screen.scale ?? 2.0
                let image = canvasView.drawing.image(from: canvasView.bounds, scale: scale)
                onSignatureChanged?(image)
            }
        }
    }
}
