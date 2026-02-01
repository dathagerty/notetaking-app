import PencilKit

// FCIS: Imperative Shell (delegate) bridging PKCanvasView events to TCA actions
class CanvasCoordinator: NSObject, PKCanvasViewDelegate {
    let onDrawingChanged: (PKDrawing) -> Void
    var toolPicker: PKToolPicker?

    init(onDrawingChanged: @escaping (PKDrawing) -> Void) {
        self.onDrawingChanged = onDrawingChanged
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        onDrawingChanged(canvasView.drawing)
    }
}
