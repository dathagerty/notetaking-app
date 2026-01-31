import SwiftUI
import ComposableArchitecture

struct LibraryView: View {
    @Bindable var store: StoreOf<LibraryFeature>

    var body: some View {
        NavigationSplitView {
            // Sidebar: Notebooks
            NotebookListView(store: store)
        } content: {
            // Content: Notes in selected notebook
            NoteListView(store: store)
        } detail: {
            // Detail: Selected note (placeholder until Phase 4)
            if let noteId = store.selectedNoteId,
               let note = store.notes.first(where: { $0.id == noteId }) {
                Text("Note: \(note.title)")
                    .font(.title)
                Text("Editor coming in Phase 4")
                    .foregroundColor(.gray)
            } else {
                Text("Select a note")
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .alert($store.scope(state: \.createNotebookAlert, action: \.createNotebookAlert))
        .alert($store.scope(state: \.createNoteAlert, action: \.createNoteAlert))
        .confirmationDialog($store.scope(state: \.deleteConfirmation, action: \.deleteConfirmation))
    }
}
