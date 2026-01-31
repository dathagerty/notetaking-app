import SwiftUI
import ComposableArchitecture

struct NotebookListView: View {
    @Bindable var store: StoreOf<LibraryFeature>

    var body: some View {
        VStack(spacing: 0) {
            // Breadcrumb navigation
            if !store.notebookPath.isEmpty {
                BreadcrumbView(
                    path: store.notebookPath,
                    onSelect: { notebookId in
                        store.send(.navigateToBreadcrumb(notebookId))
                    }
                )
            }

            List(selection: $store.selectedNotebookId.sending(\.notebookSelected)) {
                ForEach(store.notebooks) { notebook in
                    Label(notebook.name, systemImage: "folder")
                        .tag(notebook.id as UUID?)
                        .contextMenu {
                            Button("New Notebook") {
                                store.send(.showCreateNotebook(parentId: notebook.id))
                            }
                            Button("Delete", role: .destructive) {
                                store.send(.showDeleteConfirmation(item: .notebook(notebook.id)))
                            }
                        }
                }
            }
        }
        .navigationTitle("Notebooks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.send(.showCreateNotebook(parentId: nil))
                } label: {
                    Label("New Notebook", systemImage: "folder.badge.plus")
                }
            }
        }
    }
}

// Breadcrumb component for hierarchical navigation
struct BreadcrumbView: View {
    let path: [NotebookViewModel]
    let onSelect: (UUID?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button("All") {
                    onSelect(nil)
                }

                ForEach(path) { notebook in
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(notebook.name) {
                        onSelect(notebook.id)
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 40)
        .background(Color(.systemGray6))
    }
}
