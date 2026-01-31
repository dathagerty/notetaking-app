import SwiftUI
import ComposableArchitecture

struct NoteListView: View {
    @Bindable var store: StoreOf<LibraryFeature>

    var body: some View {
        Group {
            if let notebookId = store.selectedNotebookId,
               let notebook = store.notebooks.first(where: { $0.id == notebookId }) {
                List(selection: $store.selectedNoteId.sending(\.noteSelected)) {
                    ForEach(store.notes) { note in
                        NoteRowView(note: note)
                            .tag(note.id as UUID?)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    store.send(.showDeleteConfirmation(item: .note(note.id)))
                                }
                            }
                    }
                }
                .navigationTitle(notebook.name)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            store.send(.showCreateNote)
                        } label: {
                            Label("New Note", systemImage: "note.text.badge.plus")
                        }
                    }
                }
            } else {
                Text("Select a notebook")
                    .foregroundColor(.gray)
            }
        }
    }
}
