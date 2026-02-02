import ComposableArchitecture
import PencilKit
import PDFKit
import UIKit
import Foundation

// FCIS: Functional Core (TCA reducer) for PDF/image export with presentation state
@Reducer
struct ExportFeature {
    @ObservableState
    struct State: Equatable {
        var noteIds: [UUID]
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

    @Dependency(\.noteRepository) var noteRepo

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .exportButtonTapped:
                state.isExporting = true

                let noteIds = state.noteIds
                let format = state.exportFormat

                return .run { send in
                    do {
                        let url: URL

                        if noteIds.count == 1, let noteId = noteIds.first {
                            url = try await exportSingleNote(noteId: noteId, format: format)
                        } else {
                            url = try await exportMultipleNotes(noteIds: noteIds, format: format)
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
                return .none

            case .shareSheet:
                return .none
            }
        }
    }

    private func exportSingleNote(noteId: UUID, format: ExportFormat) async throws -> URL {
        guard let note = try await noteRepo.fetchNote(id: noteId) else {
            throw ExportError.noteNotFound
        }

        guard let drawingData = note.drawingData else {
            throw ExportError.noDrawing
        }

        // Use PKDrawing's native deserialization
        let drawing = try PKDrawing(data: drawingData)

        let fileName = sanitizeFileName(note.title.isEmpty ? "Untitled" : note.title)
        let tempDir = FileManager.default.temporaryDirectory

        switch format {
        case .pdf:
            let pdfURL = tempDir.appendingPathComponent("\(fileName).pdf")
            let pdfDocument = PDFDocument()
            let image = drawing.image(from: drawing.bounds, scale: 2.0)
            guard let page = PDFPage(image: image) else {
                throw ExportError.invalidDrawing
            }
            pdfDocument.insert(page, at: 0)
            pdfDocument.write(to: pdfURL)

            return pdfURL

        case .image:
            let imageURL = tempDir.appendingPathComponent("\(fileName).png")
            let image = drawing.image(from: drawing.bounds, scale: 2.0)

            guard let data = image.pngData() else {
                throw ExportError.invalidDrawing
            }
            try data.write(to: imageURL)

            return imageURL
        }
    }

    private func exportMultipleNotes(noteIds: [UUID], format: ExportFormat) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let exportDir = tempDir.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)

        for noteId in noteIds {
            do {
                let url = try await exportSingleNote(noteId: noteId, format: format)

                let fileName = url.lastPathComponent
                let destination = exportDir.appendingPathComponent(fileName)
                try FileManager.default.copyItem(at: url, to: destination)
            } catch {
                // Skip notes that fail to export
                continue
            }
        }

        // For iOS 17+, we use a folder approach for multiple files
        // iOS does not provide FileManager.zipItem() - would need external dependency for ZIP
        // The folder is shared via UIActivityViewController which can handle multiple files
        // or the folder itself for transfer to Files app
        return exportDir
    }

    private func sanitizeFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: invalid).joined(separator: "-")
    }
}

enum ExportError: Error {
    case noteNotFound
    case noDrawing
    case invalidDrawing
    case exportFailed
}
