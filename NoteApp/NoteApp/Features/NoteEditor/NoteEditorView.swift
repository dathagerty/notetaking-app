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
                    store.send(.gestureDetected(.drawingStarted))
                }
            )
            .ignoresSafeArea()
            .persistentSystemOverlays(.hidden) // Hide home indicator

            // Auto-hiding navigation overlay
            if store.navigationVisible {
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
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Invisible double-tap detection zone at top edge
            VStack {
                Color.clear
                    .frame(height: 60)
                    .contentShape(Rectangle())
                    .gesture(
                        TapGesture(count: 2)
                            .onEnded {
                                store.send(.gestureDetected(.topEdgeDoubleTap))
                            }
                    )

                Spacer()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.navigationVisible)
        .onAppear {
            store.send(.onAppear)
            store.send(.hideNavigationAfterDelay)
        }
        .confirmationDialog(
            $store.scope(
                state: \.exitConfirmation,
                action: \.exitConfirmation
            )
        )
        .interactiveDismissDisabled(store.hasUnsavedChanges)
    }
}

#Preview {
    NoteEditorView(
        store: Store(
            initialState: NoteEditorFeature.State(
                noteId: UUID(),
                noteTitle: "Test Note",
                drawing: PKDrawing()
            ),
            reducer: { NoteEditorFeature() }
        )
    )
}
