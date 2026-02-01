import PencilKit

class CanvasCoordinator: NSObject, PKCanvasViewDelegate {
    let onDrawingChanged: (PKDrawing) -> Void

    init(onDrawingChanged: @escaping (PKDrawing) -> Void) {
        self.onDrawingChanged = onDrawingChanged
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        onDrawingChanged(canvasView.drawing)
    }
}
