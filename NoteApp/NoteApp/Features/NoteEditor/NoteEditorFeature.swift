import ComposableArchitecture
import PencilKit
import Foundation

@Reducer
struct NoteEditorFeature {
    @ObservableState
    struct State: Equatable {
        var note: Note
        var drawing: PKDrawing
        var hasUnsavedChanges: Bool = false
        var isSaving: Bool = false
        @Presents var exitConfirmation: ConfirmationDialogState<Action.ExitConfirmation>?
    }

    enum Action: Equatable {
        case onAppear
        case drawingChanged(PKDrawing)
        case saveDrawing
        case drawingSaved
        case saveFailed(String)
        case closeButtonTapped
        case exitConfirmation(PresentationAction<ExitConfirmation>)

        enum ExitConfirmation: Equatable {
            case confirmExit
            case cancelExit
        }
    }

    @Dependency(\.noteRepository) var noteRepo
    @Dependency(\.continuousClock) var clock

    enum CancelID { case save }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // Load existing drawing if available
                if let data = state.note.drawingData {
                    do {
                        // Use PKDrawing's native deserialization
                        let drawing = try PKDrawing(data: data)
                        state.drawing = drawing
                    } catch {
                        state.drawing = PKDrawing()
                    }
                } else {
                    state.drawing = PKDrawing()
                }
                return .none

            case .drawingChanged(let newDrawing):
                state.drawing = newDrawing
                state.hasUnsavedChanges = true

                // Debounced auto-save (2 seconds after drawing stops)
                return .run { send in
                    try await clock.sleep(for: .seconds(2))
                    await send(.saveDrawing)
                }
                .cancellable(id: CancelID.save, cancelInFlight: true)

            case .saveDrawing:
                guard state.hasUnsavedChanges else { return .none }
                state.isSaving = true

                let drawing = state.drawing
                let note = state.note

                return .run { send in
                    do {
                        // Use PKDrawing's native serialization
                        let data = drawing.dataRepresentation()

                        // Update note via repository
                        note.drawingData = data
                        note.updatedAt = Date()
                        try await noteRepo.updateNote(note)

                        await send(.drawingSaved)
                    } catch {
                        await send(.saveFailed(error.localizedDescription))
                    }
                }

            case .drawingSaved:
                state.hasUnsavedChanges = false
                state.isSaving = false
                return .none

            case .saveFailed(let error):
                state.isSaving = false
                print("Save failed: \(error)")
                // Retry save automatically after 5 seconds
                return .run { send in
                    try await clock.sleep(for: .seconds(5))
                    await send(.saveDrawing)
                }

            case .closeButtonTapped:
                if state.hasUnsavedChanges {
                    state.exitConfirmation = ConfirmationDialogState {
                        TextState("Unsaved Changes")
                    } actions: {
                        ButtonState(role: .destructive, action: .confirmExit) {
                            TextState("Discard Changes")
                        }
                        ButtonState(role: .cancel, action: .cancelExit) {
                            TextState("Keep Editing")
                        }
                    } message: {
                        TextState("You have unsaved changes. Discard them?")
                    }
                    return .none
                }
                // No unsaved changes, exit immediately
                return .none

            case .exitConfirmation(.presented(.confirmExit)):
                // Actually handle exit in parent (LibraryFeature)
                return .none

            case .exitConfirmation:
                return .none
            }
        }
        .ifLet(\.$exitConfirmation, action: \.exitConfirmation)
    }
}
