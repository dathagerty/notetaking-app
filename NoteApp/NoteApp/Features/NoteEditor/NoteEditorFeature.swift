import ComposableArchitecture
import PencilKit
import Foundation

// FCIS: Functional Core (reducer logic) with Imperative Shell (TCA integration)
// Manages note editing state: drawing changes, persistence, and exit confirmation



@Reducer
struct NoteEditorFeature {
    @ObservableState
    struct State: Equatable {
        var noteId: UUID
        var noteTitle: String
        var drawing: PKDrawing
        var hasUnsavedChanges: Bool = false
        var isSaving: Bool = false
        @Presents var exitConfirmation: ConfirmationDialogState<ExitConfirmation>?
    }

    @CasePathable
    enum Delegate: Equatable, Sendable {
        case closeRequested
    }

    @CasePathable
    enum ExitConfirmation: Equatable, Sendable {
        case confirmExit
        case cancelExit
    }

    @CasePathable
    enum Action {
        case onAppear
        case drawingLoaded(PKDrawing)
        case drawingChanged(PKDrawing)
        case saveDrawing
        case drawingSaved
        case saveFailed(String)
        case closeButtonTapped
        case exitConfirmation(PresentationAction<ExitConfirmation>)
        case delegate(Delegate)
    }

    @Dependency(\.noteRepository) var noteRepo
    @Dependency(\.continuousClock) var clock

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let noteId = state.noteId
                return .run { send in
                    do {
                        if let note = try await noteRepo.fetchNote(id: noteId),
                           let drawingData = note.drawingData {
                            let drawing = try PKDrawing(data: drawingData)
                            await send(.drawingLoaded(drawing))
                        } else {
                            await send(.drawingLoaded(PKDrawing()))
                        }
                    } catch {
                        await send(.drawingLoaded(PKDrawing()))
                    }
                }

            case .drawingLoaded(let drawing):
                state.drawing = drawing
                return .none

            case .drawingChanged(let newDrawing):
                state.drawing = newDrawing
                state.hasUnsavedChanges = true

                // Debounced auto-save (2 seconds after drawing stops)
                return .run { send in
                    try await clock.sleep(for: .seconds(2))
                    await send(.saveDrawing)
                }
                .cancellable(id: "NoteEditorSave", cancelInFlight: true)

            case .saveDrawing:
                guard state.hasUnsavedChanges else { return .none }
                state.isSaving = true

                let noteId = state.noteId
                let drawingData = state.drawing.dataRepresentation()

                return .run { send in
                    do {
                        try await noteRepo.updateDrawingData(
                            noteId: noteId,
                            drawingData: drawingData
                        )
                        await send(.drawingSaved)
                    } catch {
                        await send(.saveFailed(error.localizedDescription))
                    }
                }

            case .drawingSaved:
                state.hasUnsavedChanges = false
                state.isSaving = false
                return .cancel(id: "NoteEditorRetry")

            case .saveFailed:
                state.isSaving = false
                // Retry save automatically after 5 seconds
                return .run { send in
                    try await clock.sleep(for: .seconds(5))
                    await send(.saveDrawing)
                }
                .cancellable(id: "NoteEditorRetry", cancelInFlight: true)

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
                return .send(.delegate(.closeRequested))

            case .exitConfirmation(.presented(.confirmExit)):
                return .send(.delegate(.closeRequested))

            case .exitConfirmation(.presented(.cancelExit)):
                return .none

            case .exitConfirmation(.dismiss):
                return .none

            case .delegate:
                // Handled by parent
                return .none
            }
        }
        .ifLet(\.$exitConfirmation, action: \.exitConfirmation)
    }
}
