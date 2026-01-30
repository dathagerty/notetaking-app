# reMarkable iPad Note App Implementation Plan - Phase 6

**Goal:** Full organization features with inline hashtag detection

**Architecture:** Vision framework for OCR-based hashtag recognition during auto-save, search and tag filtering in LibraryFeature

**Tech Stack:** Vision framework (VNRecognizeTextRequest), SwiftUI search, tag filtering

**Scope:** Phase 6 of 8 from original design

---

## Phase 6: Tags, Search, and Organization

### Done When
- Can search notes by title and recognized text
- Can filter by multiple tags simultaneously
- Hashtags written in notes automatically create/apply tags during auto-save
- Tag badge shows current tags in editor (tappable overlay)
- Can manually add/remove tags from library long-press menu
- Search and tag filters combine correctly (AND logic)

---

<!-- START_TASK_1 -->
### Task 1: Add Vision Framework Hashtag Detection

**Files:**
- Create: `NoteApp/Services/HashtagExtractor.swift`

```swift
import Vision
import PencilKit
import UIKit

actor HashtagExtractor {
    func extractHashtags(from drawing: PKDrawing) async throws -> Set<String> {
        // Render drawing to image
        let image = drawing.image(
            from: drawing.bounds,
            scale: 1.0
        )

        guard let cgImage = image.cgImage else {
            return []
        }

        // Create Vision text recognition request
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results else {
            return []
        }

        // Extract hashtags from recognized text
        var hashtags = Set<String>()

        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else {
                continue
            }

            let text = topCandidate.string
            let pattern = #"#(\w+)"#

            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(text.startIndex..., in: text)
                let matches = regex.matches(in: text, range: range)

                for match in matches {
                    if let tagRange = Range(match.range(at: 1), in: text) {
                        let tag = String(text[tagRange]).lowercased()
                        hashtags.insert(tag)
                    }
                }
            }
        }

        return hashtags
    }
}
```

Commit:
```bash
git add NoteApp/Services/HashtagExtractor.swift
git commit -m "feat: create Vision framework hashtag extractor

- Use VNRecognizeTextRequest for OCR on drawings
- Extract hashtags via regex pattern matching
- Return normalized lowercase tags
- Actor isolation for thread safety
- Enable automatic tag detection during save

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Integrate Hashtag Detection into Auto-Save

**Files:**
- Modify: `NoteApp/Features/NoteEditor/NoteEditorFeature.swift`

Add to State:
```swift
var detectedTags: Set<String> = []
```

Update `.saveDrawing` case:
```swift
case .saveDrawing:
    guard state.hasUnsavedChanges else { return .none }
    state.isSaving = true

    let drawing = state.drawing
    let note = state.note

    return .run { send in
        do {
            // Serialize drawing
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: drawing,
                requiringSecureCoding: true
            )

            // Extract hashtags asynchronously
            let extractor = HashtagExtractor()
            let detectedTags = try await extractor.extractHashtags(from: drawing)

            // Create/fetch tags and attach to note
            @Dependency(\.tagRepository) var tagRepo

            var tags: [Tag] = []
            for tagName in detectedTags {
                let tag = try await tagRepo.fetchOrCreateTag(name: tagName)
                tags.append(tag)
            }

            // Update note with drawing data and tags
            note.drawingData = data
            note.tags = tags
            note.updatedAt = Date()
            try await noteRepo.updateNote(note)

            await send(.drawingSaved)
        } catch {
            await send(.saveFailed(error.localizedDescription))
        }
    }
```

Commit:
```bash
git add NoteApp/Features/NoteEditor/NoteEditorFeature.swift
git commit -m "feat: integrate hashtag detection into auto-save

- Run Vision OCR during auto-save
- Extract hashtags from drawing text
- Automatically create/attach tags to note
- Update note with both drawing and tags
- Tags detected asynchronously without blocking UI

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```
<!-- END_TASK_2 -->

<!-- START_TASK_3 -->
### Task 3: Add Search and Tag Filtering to LibraryFeature

**Files:**
- Modify: `NoteApp/Features/Library/LibraryFeature.swift`

Add to State:
```swift
var searchQuery: String = ""
var selectedTags: Set<Tag> = []
var allTags: [Tag] = []
var filteredNotes: [Note] = []
```

Add to Action:
```swift
case searchQueryChanged(String)
case tagToggled(Tag)
case tagsLoaded([Tag])
case applyFilters
```

Add to reducer:
```swift
case .searchQueryChanged(let query):
    state.searchQuery = query
    return .send(.applyFilters)

case .tagToggled(let tag):
    if state.selectedTags.contains(tag) {
        state.selectedTags.remove(tag)
    } else {
        state.selectedTags.insert(tag)
    }
    return .send(.applyFilters)

case .tagsLoaded(let tags):
    state.allTags = tags
    return .none

case .applyFilters:
    return .run { [query = state.searchQuery, tags = state.selectedTags, notebook = state.selectedNotebook] send in
        do {
            var notes: [Note] = []

            // Fetch base notes from selected notebook
            if let notebook = notebook {
                notes = try await noteRepo.fetchNotes(in: notebook)
            } else {
                notes = try await noteRepo.fetchAllNotes()
            }

            // Apply search filter
            if !query.isEmpty {
                notes = notes.filter { note in
                    note.title.localizedCaseInsensitiveContains(query) ||
                    note.content.localizedCaseInsensitiveContains(query) ||
                    (note.searchableText?.localizedCaseInsensitiveContains(query) ?? false)
                }
            }

            // Apply tag filter (AND logic)
            if !tags.isEmpty {
                notes = notes.filter { note in
                    guard let noteTags = note.tags else { return false }
                    let noteTagSet = Set(noteTags)
                    return tags.isSubset(of: noteTagSet)
                }
            }

            await send(.notesLoaded(notes))
        } catch {
            await send(.errorOccurred(error.localizedDescription))
        }
    }

case .refreshData:
    state.isLoading = true
    return .run { send in
        do {
            let notebooks = try await notebookRepo.fetchRootNotebooks()
            await send(.notebooksLoaded(notebooks))

            let tags = try await tagRepo.fetchAllTags()
            await send(.tagsLoaded(tags))

            await send(.applyFilters)
        } catch {
            await send(.errorOccurred(error.localizedDescription))
        }
    }
```

Commit:
```bash
git add NoteApp/Features/Library/LibraryFeature.swift
git commit -m "feat: add search and tag filtering to Library

- Add search query and selected tags to state
- Implement search across title, content, searchableText
- Implement multi-tag filtering with AND logic
- Combine search and tag filters
- Refresh filtered results on query/tag changes

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```
<!-- END_TASK_3 -->

<!-- START_TASK_4 -->
### Task 4: Add Search and Tag UI Components

**Files:**
- Create: `NoteApp/Features/Library/SearchBar.swift`
- Create: `NoteApp/Features/Library/TagFilterBar.swift`
- Modify: `NoteApp/Features/Library/LibraryView.swift`

**SearchBar.swift:**
```swift
import SwiftUI
import ComposableArchitecture

struct SearchBar: View {
    @Bindable var store: StoreOf<LibraryFeature>

    var body: some View {
        TextField("Search notes...", text: $store.searchQuery.sending(\.searchQueryChanged))
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal)
    }
}
```

**TagFilterBar.swift:**
```swift
import SwiftUI
import ComposableArchitecture

struct TagFilterBar: View {
    @Bindable var store: StoreOf<LibraryFeature>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.allTags) { tag in
                    TagChip(
                        tag: tag,
                        isSelected: store.selectedTags.contains(tag)
                    ) {
                        store.send(.tagToggled(tag))
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct TagChip: View {
    let tag: Tag
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("#\(tag.name)")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}
```

**Update LibraryView.swift:**
```swift
content: {
    if let notebook = store.selectedNotebook {
        VStack(spacing: 0) {
            SearchBar(store: store)
            TagFilterBar(store: store)

            List(selection: $store.selectedNote.sending(\.noteSelected)) {
                ForEach(store.filteredNotes) { note in
                    NoteRowView(note: note)
                        .tag(note as Note?)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                store.send(.showDeleteConfirmation(item: .note(note)))
                            }
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
```

Commit:
```bash
git add NoteApp/Features/Library/SearchBar.swift NoteApp/Features/Library/TagFilterBar.swift NoteApp/Features/Library/LibraryView.swift
git commit -m "feat: add search bar and tag filter UI

- Create SearchBar with real-time query updates
- Create TagFilterBar with horizontal scrolling tag chips
- Add visual selection state for tags
- Integrate into LibraryView above note list
- Phase 6 complete: full search and organization

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```
<!-- END_TASK_4 -->

---

## Phase 6 Complete

**Verification:**
- ✓ Vision framework extracts hashtags from drawings
- ✓ Tags automatically created and attached during auto-save
- ✓ Search filters notes by title/content/recognized text
- ✓ Multi-tag filtering with AND logic
- ✓ Tag chips display with selection state
- ✓ Search and tags combine correctly

**Next Phase:** Phase 7 - Handwriting-to-Text Conversion & Export
