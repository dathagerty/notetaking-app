import SwiftUI
import ComposableArchitecture

struct NoteListView: View {
    @Bindable var store: StoreOf<LibraryFeature>

    var body: some View {
        Group {
            if let notebookId = store.selectedNotebookId {
                let notebookName = store.notebooks.first(where: { $0.id == notebookId })?.name ?? "Notebook"
                VStack(spacing: 0) {
                    SearchBar(store: store)
                    TagFilterBar(store: store)

                    List(selection: $store.selectedNoteId.sending(\.noteSelected)) {
                        ForEach(store.filteredNotes) { note in
                            NoteRowView(
                                note: note,
                                isConverting: store.convertingNoteId == note.id
                            )
                                .tag(note.id as UUID?)
                                .contextMenu {
                                    Button {
                                        store.send(.convertHandwriting(noteId: note.id))
                                    } label: {
                                        Label("Convert Handwriting", systemImage: "doc.text.magnifyingglass")
                                    }

                                    Button {
                                        store.send(.showManageTagsSheet(noteId: note.id))
                                    } label: {
                                        Label("Manage Tags", systemImage: "tag.fill")
                                    }

                                    Button("Delete", role: .destructive) {
                                        store.send(.showDeleteConfirmation(item: .note(note.id)))
                                    }
                                }
                        }
                    }
                }
                .navigationTitle(notebookName)
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
