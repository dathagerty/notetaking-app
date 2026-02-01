import SwiftUI
import ComposableArchitecture
import PencilKit

// FCIS: Imperative Shell (view layer) displaying note editor with canvas and controls
struct NoteEditorView: View {
    @Bindable var store: StoreOf<NoteEditorFeature>

    var body: some View {
        ZStack {
            // Full-screen canvas
            CanvasView(
                drawing: store.drawing,
                onDrawingChanged: { newDrawing in
                    store.send(.drawingChanged(newDrawing))
                }
            )
            .ignoresSafeArea()

            // Minimal navigation bar (will auto-hide in Phase 5)
            VStack {
                HStack {
                    Button {
                        store.send(.closeButtonTapped)
                    } label: {
                        Label("Close", systemImage: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.primary)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Spacer()

                    if store.isSaving {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Saving...")
                                .font(.caption)
                        }
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                }
                .padding()

                Spacer()
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .confirmationDialog(
            $store.scope(
                state: \.exitConfirmation,
                action: \.exitConfirmation
            )
        )
    }
}

#Preview {
    NoteEditorView(
        store: Store(
            initialState: NoteEditorFeature.State(
                note: Note(title: "Test Note"),
                drawing: PKDrawing()
            ),
            reducer: { NoteEditorFeature() }
        )
    )
}
