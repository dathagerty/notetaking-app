import SwiftUI
import PencilKit

struct CanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    let onDrawingChanged: (PKDrawing) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()

        // Configure canvas
        canvasView.drawing = drawing
        canvasView.drawingPolicy = .anyInput // Allow Apple Pencil and finger
        canvasView.delegate = context.coordinator

        // Show tool picker
        let toolPicker = PKToolPicker()
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Update drawing if changed externally
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
    }

    func makeCoordinator() -> CanvasCoordinator {
        CanvasCoordinator(onDrawingChanged: onDrawingChanged)
    }
}
