import SwiftUI
import ComposableArchitecture
import PencilKit

// FCIS: Imperative Shell (view layer) for Library navigation and notebook/note management
struct LibraryView: View {
    @Bindable var store: StoreOf<LibraryFeature>

    var body: some View {
        mainContent
            .onAppear {
                store.send(.onAppear)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.send(.showCreateNote)
                    } label: {
                        Label("New Note", systemImage: "note.text.badge.plus")
                    }
                }

                ToolbarItem(placement: .status) {
                    HStack(spacing: 4) {
                        // Network status
                        Image(systemName: store.isOnline ? "wifi" : "wifi.slash")
                            .foregroundColor(store.isOnline ? .green : .orange)

                        // Sync status
                        if let lastSync = store.lastSyncDate {
                            Text("Synced \(lastSync, style: .relative)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let _ = store.syncError {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .accessibilityLabel("Sync error occurred")
                                .accessibilityHint("CloudKit synchronization encountered an error. Check your network connection and try again.")
                        }
                    }
                }
            }
            .sheet(item: createNotebookSheetBinding) { sheetState in
                CreateNotebookSheetView(
                    state: sheetState,
                    onNameChanged: { store.send(.createNotebookSheet(.notebookNameChanged($0))) },
                    onCreate: { store.send(.createNotebookSheet(.createButtonTapped)) }
                )
            }
            .sheet(item: createNoteSheetBinding) { sheetState in
                CreateNoteSheetView(
                    state: sheetState,
                    onTitleChanged: { store.send(.createNoteSheet(.noteTitleChanged($0))) },
                    onCreate: { store.send(.createNoteSheet(.createButtonTapped)) }
                )
            }
            .confirmationDialog(
                "Delete?",
                isPresented: deleteDialogBinding,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    store.send(.deleteConfirmation(.presented(.confirmDelete)))
                }
                Button("Cancel", role: .cancel) {
                    store.send(.deleteConfirmation(.dismiss))
                }
            } message: {
                if let confirmation = store.deleteConfirmation,
                   let message = confirmation.message {
                    Text(String(state: message))
                }
            }
            .sheet(isPresented: shareSheetPresented) {
                if let url = store.exportFeature?.shareSheet?.url {
                    ShareSheet(url: url) {
                        store.send(.exportFeature(.presented(.shareSheet(.dismiss))))
                    }
                }
            }
            .alert(
                $store.scope(state: \.errorAlert, action: \.errorAlert)
            )
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { store.deleteConfirmation != nil },
            set: { if !$0 { store.send(.deleteConfirmation(.dismiss)) } }
        )
    }

    private var createNotebookSheetBinding: Binding<CreateNotebookSheetState?> {
        Binding(
            get: { store.createNotebookSheet },
            set: { _ in }
        )
    }

    private var createNoteSheetBinding: Binding<CreateNoteSheetState?> {
        Binding(
            get: { store.createNoteSheet },
            set: { _ in }
        )
    }

    private var shareSheetPresented: Binding<Bool> {
        Binding(
            get: { store.exportFeature?.shareSheet != nil },
            set: { if !$0 { store.send(.exportFeature(.presented(.shareSheet(.dismiss)))) } }
        )
    }

    @ViewBuilder
    private var mainContent: some View {
        NavigationSplitView {
            NotebookListView(store: store)
        } content: {
            NoteListView(store: store)
        } detail: {
            detailContent
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if store.selectedNote != nil {
            if let editorStore = store.scope(
                state: \.noteEditor,
                action: \.noteEditor.presented
            ) {
                NoteEditorView(store: editorStore)
            } else {
                loadingEditorView
            }
        } else {
            emptyStateView
        }
    }

    private var loadingEditorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(store.selectedNote?.title ?? "Untitled")
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

    private var emptyStateView: some View {
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

struct CreateNotebookSheetView: View {
    let state: CreateNotebookSheetState
    let onNameChanged: (String) -> Void
    let onCreate: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var notebookName: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Notebook name", text: $notebookName)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .onChange(of: notebookName) { _, newValue in
                        onNameChanged(newValue)
                    }

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
                        onCreate()
                        dismiss()
                    }
                    .disabled(notebookName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                notebookName = state.notebookName
            }
        }
    }
}

struct CreateNoteSheetView: View {
    let state: CreateNoteSheetState
    let onTitleChanged: (String) -> Void
    let onCreate: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var noteTitle: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Note title", text: $noteTitle)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .onChange(of: noteTitle) { _, newValue in
                        onTitleChanged(newValue)
                    }

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
                        onCreate()
                        dismiss()
                    }
                }
            }
            .onAppear {
                noteTitle = state.noteTitle
            }
        }
    }
}
