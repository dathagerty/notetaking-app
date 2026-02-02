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
