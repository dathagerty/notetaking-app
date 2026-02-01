import SwiftUI
import PencilKit

// FCIS: Imperative Shell (UIKit bridge) for PencilKit canvas drawing
struct CanvasView: UIViewRepresentable {
    let drawing: PKDrawing
    let onDrawingChanged: (PKDrawing) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()

        // Configure canvas
        canvasView.drawing = drawing
        canvasView.drawingPolicy = .anyInput // Allow Apple Pencil and finger
        canvasView.delegate = context.coordinator

        // Show tool picker with strong reference to prevent deallocation
        let toolPicker = PKToolPicker()
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()

        // Store tool picker in coordinator to retain it
        context.coordinator.toolPicker = toolPicker

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
