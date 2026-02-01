import SwiftUI
import ComposableArchitecture
import PencilKit

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
            // Detail: Note editor or empty state
            if let note = store.selectedNote {
                if let editorStore = store.scope(
                    state: \.noteEditor,
                    action: \.noteEditor
                ) {
                    NoteEditorView(store: editorStore)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text(note.title.isEmpty ? "Untitled" : note.title)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Loading editor...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.ellipsis")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No Note Selected")
                        .font(.headline)

                    Text("Select a note from the list to view or edit")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .sheet(
            item: $store.scope(state: \.createNotebookSheet, action: \.createNotebookSheet),
            content: { notebookSheetStore in
                CreateNotebookSheetView(store: notebookSheetStore)
            }
        )
        .sheet(
            item: $store.scope(state: \.createNoteSheet, action: \.createNoteSheet),
            content: { noteSheetStore in
                CreateNoteSheetView(store: noteSheetStore)
            }
        )
        .confirmationDialog($store.scope(state: \.deleteConfirmation, action: \.deleteConfirmation))
    }
}

struct CreateNotebookSheetView: View {
    @Bindable var store: StoreOf<LibraryFeature>.Scope<LibraryFeature.CreateNotebookSheetState, LibraryFeature.CreateNotebookSheetAction>
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Notebook name", text: $store.notebookName.sending(\.notebookNameChanged))
                    .textFieldStyle(.roundedBorder)
                    .padding()

                Spacer()
            }
            .navigationTitle("New Notebook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        store.send(.createButtonTapped)
                        dismiss()
                    }
                    .disabled(store.notebookName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct CreateNoteSheetView: View {
    @Bindable var store: StoreOf<LibraryFeature>.Scope<LibraryFeature.CreateNoteSheetState, LibraryFeature.CreateNoteSheetAction>
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Note title", text: $store.noteTitle.sending(\.noteTitleChanged))
                    .textFieldStyle(.roundedBorder)
                    .padding()

                Spacer()
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        store.send(.createButtonTapped)
                        dismiss()
                    }
                }
            }
        }
    }
}
