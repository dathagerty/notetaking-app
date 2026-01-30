# reMarkable iPad Note App Implementation Plan - Phase 7

**Goal:** Text recognition for search and PDF/image export

**Architecture:** HandwritingRecognition service with Vision framework, ExportFeature for PDF/image generation, UIActivityViewController integration

**Tech Stack:** Vision framework (full text recognition), PDFKit, UIActivityViewController, ZipArchive

**Scope:** Phase 7 of 8 from original design

---

## Phase 7: Handwriting-to-Text Conversion & Export

### Done When
- Long-press note shows "Convert Handwriting" option
- Vision framework extracts text to searchableText
- Progress indicator during conversion
- Search finds notes by converted text
- Can export single note as PDF or image
- Can export multiple notes as ZIP
- Share sheet appears with Files/AirDrop
- Exported files have meaningful names

---

<!-- START_TASK_1 -->
### Task 1: Create Handwriting Recognition Service

**Files:**
- Create: `NoteApp/Services/HandwritingRecognition.swift`

```swift
import Vision
import PencilKit
import UIKit

actor HandwritingRecognitionService {
    func recognizeText(from drawing: PKDrawing) async throws -> String {
        // Render drawing to image
        let image = drawing.image(
            from: drawing.bounds,
            scale: 2.0 // Higher scale for better recognition
        )

        guard let cgImage = image.cgImage else {
            throw RecognitionError.invalidImage
        }

        // Create Vision text recognition request
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results else {
            return ""
        }

        // Combine all recognized text
        let recognizedStrings = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }

        return recognizedStrings.joined(separator: " ")
    }
}

enum RecognitionError: Error {
    case invalidImage
    case recognitionFailed
}
```

Commit:
```bash
git add NoteApp/Services/HandwritingRecognition.swift
git commit -m "feat: create handwriting recognition service

- Use Vision framework for full text extraction
- Higher scale rendering for better accuracy
- Language correction enabled
- Combine recognized text blocks
- Actor isolation for thread safety

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Add Convert Handwriting Action to LibraryFeature

**Files:**
- Modify: `NoteApp/Features/Library/LibraryFeature.swift`

Add to State:
```swift
var convertingNoteId: UUID? = nil
```

Add to Action:
```swift
case convertHandwriting(Note)
case handwritingConverted(noteId: UUID, text: String)
case conversionFailed(String)
```

Add to reducer:
```swift
case .convertHandwriting(let note):
    state.convertingNoteId = note.id

    return .run { send in
        do {
            guard let drawingData = note.drawingData else {
                throw RecognitionError.invalidImage
            }

            let drawing = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: PKDrawing.self,
                from: drawingData
            )

            guard let drawing = drawing else {
                throw RecognitionError.invalidImage
            }

            let recognitionService = HandwritingRecognitionService()
            let text = try await recognitionService.recognizeText(from: drawing)

            note.searchableText = text
            try await noteRepo.updateNote(note)

            await send(.handwritingConverted(noteId: note.id, text: text))
        } catch {
            await send(.conversionFailed(error.localizedDescription))
        }
    }

case .handwritingConverted(let noteId, let text):
    state.convertingNoteId = nil
    print("Converted note \(noteId): \(text.prefix(100))...")
    return .send(.refreshData)

case .conversionFailed(let error):
    state.convertingNoteId = nil
    state.errorMessage = "Conversion failed: \(error)"
    return .none
```

Update context menu in `NoteListView.swift`:
```swift
.contextMenu {
    Button {
        store.send(.convertHandwriting(note))
    } label: {
        Label("Convert Handwriting", systemImage: "doc.text.magnifyingglass")
    }

    Button("Delete", role: .destructive) {
        store.send(.showDeleteConfirmation(item: .note(note)))
    }
}
```

Commit:
```bash
git add NoteApp/Features/Library/LibraryFeature.swift NoteApp/Features/Library/NoteListView.swift
git commit -m "feat: add handwriting conversion to Library

- Add convert handwriting action to context menu
- Extract text via HandwritingRecognitionService
- Store recognized text in searchableText field
- Show progress with convertingNoteId state
- Enable search by converted text

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```
<!-- END_TASK_2 -->

<!-- START_TASK_3 -->
### Task 3: Create Export Feature

**Files:**
- Create: `NoteApp/Features/Library/ExportFeature.swift`

```swift
import ComposableArchitecture
import PencilKit
import PDFKit
import UIKit
import ZipArchive

@Reducer
struct ExportFeature {
    @ObservableState
    struct State: Equatable {
        var notesToExport: [Note]
        var exportFormat: ExportFormat = .pdf
        var isExporting: Bool = false
        @Presents var shareSheet: ShareSheetState?
    }

    enum Action: Equatable {
        case exportButtonTapped
        case exportCompleted(URL)
        case exportFailed(String)
        case shareSheet(PresentationAction<ShareSheetAction>)
    }

    enum ExportFormat: String, Equatable {
        case pdf
        case image
    }

    enum ShareSheetAction: Equatable {
        case dismiss
    }

    struct ShareSheetState: Equatable {
        let url: URL
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .exportButtonTapped:
                state.isExporting = true

                let notes = state.notesToExport
                let format = state.exportFormat

                return .run { send in
                    do {
                        let url: URL

                        if notes.count == 1, let note = notes.first {
                            url = try await exportSingleNote(note, format: format)
                        } else {
                            url = try await exportMultipleNotes(notes, format: format)
                        }

                        await send(.exportCompleted(url))
                    } catch {
                        await send(.exportFailed(error.localizedDescription))
                    }
                }

            case .exportCompleted(let url):
                state.isExporting = false
                state.shareSheet = ShareSheetState(url: url)
                return .none

            case .exportFailed(let error):
                state.isExporting = false
                print("Export failed: \(error)")
                return .none

            case .shareSheet:
                return .none
            }
        }
        .ifLet(\.$shareSheet, action: \.shareSheet) {
            EmptyReducer()
        }
    }

    private func exportSingleNote(_ note: Note, format: ExportFormat) async throws -> URL {
        guard let drawingData = note.drawingData else {
            throw ExportError.noDrawing
        }

        let drawing = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: PKDrawing.self,
            from: drawingData
        )

        guard let drawing = drawing else {
            throw ExportError.invalidDrawing
        }

        let fileName = sanitizeFileName(note.title.isEmpty ? "Untitled" : note.title)
        let tempDir = FileManager.default.temporaryDirectory

        switch format {
        case .pdf:
            let pdfURL = tempDir.appendingPathComponent("\(fileName).pdf")
            let pdfData = drawing.dataRepresentation()

            let pdfDocument = PDFDocument()
            let page = PDFPage(image: drawing.image(from: drawing.bounds, scale: 2.0))
            pdfDocument.insert(page!, at: 0)
            pdfDocument.write(to: pdfURL)

            return pdfURL

        case .image:
            let imageURL = tempDir.appendingPathComponent("\(fileName).png")
            let image = drawing.image(from: drawing.bounds, scale: 2.0)

            if let data = image.pngData() {
                try data.write(to: imageURL)
            }

            return imageURL
        }
    }

    private func exportMultipleNotes(_ notes: [Note], format: ExportFormat) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let exportDir = tempDir.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)

        for note in notes {
            guard let url = try? await exportSingleNote(note, format: format) else {
                continue
            }

            let fileName = url.lastPathComponent
            let destination = exportDir.appendingPathComponent(fileName)
            try FileManager.default.copyItem(at: url, to: destination)
        }

        // Create ZIP
        let zipURL = tempDir.appendingPathComponent("notes-export.zip")
        SSZipArchive.createZipFile(atPath: zipURL.path, withContentsOfDirectory: exportDir.path)

        return zipURL
    }

    private func sanitizeFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: invalid).joined(separator: "-")
    }
}

enum ExportError: Error {
    case noDrawing
    case invalidDrawing
    case exportFailed
}
```

Commit:
```bash
git add NoteApp/Features/Library/ExportFeature.swift
git commit -m "feat: create export feature for PDF and images

- Add ExportFeature with TCA state management
- Support single note export (PDF/image)
- Support batch export with ZIP creation
- Generate meaningful file names from note titles
- Prepare for share sheet integration

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```
<!-- END_TASK_3 -->

<!-- START_TASK_4 -->
### Task 4: Integrate Share Sheet

**Files:**
- Create: `NoteApp/Features/Library/ShareSheet.swift`
- Modify: `NoteApp/Features/Library/LibraryView.swift`

**ShareSheet.swift:**
```swift
import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        activityVC.completionWithItemsHandler = { _, _, _, _ in
            onDismiss()
        }

        return activityVC
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
```

Update `NoteListView.swift` context menu:
```swift
.contextMenu {
    Button {
        store.send(.convertHandwriting(note))
    } label: {
        Label("Convert Handwriting", systemImage: "doc.text.magnifyingglass")
    }

    Button {
        store.send(.exportNote(note))
    } label: {
        Label("Export", systemImage: "square.and.arrow.up")
    }

    Button("Delete", role: .destructive) {
        store.send(.showDeleteConfirmation(item: .note(note)))
    }
}
```

Commit:
```bash
git add NoteApp/Features/Library/ShareSheet.swift NoteApp/Features/Library/LibraryView.swift NoteApp/Features/Library/NoteListView.swift
git commit -m "feat: integrate iOS share sheet for exports

- Create ShareSheet UIViewControllerRepresentable
- Add export option to note context menu
- Present share sheet with exported file
- Enable Files app, AirDrop, Messages sharing
- Phase 7 complete: full export and text recognition

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```
<!-- END_TASK_4 -->

---

## Phase 7 Complete

**Verification:**
- ✓ Handwriting recognition extracts full text
- ✓ Searchable text enables comprehensive search
- ✓ PDF export generates from drawings
- ✓ Image export with 2x scale
- ✓ Batch export creates ZIP
- ✓ Share sheet appears with system options
- ✓ File names derived from note titles

**Next Phase:** Phase 8 - Error Handling, Offline Support, and Polish
