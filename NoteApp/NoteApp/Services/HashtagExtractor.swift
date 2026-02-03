import Vision
import PencilKit
import UIKit

// FCIS: Functional Core with Imperative Shell
// - Functional Core: extractHashtagsFromText pure function for regex parsing (testable, no side effects)
// - Imperative Shell: extractHashtags uses Vision framework I/O for OCR text extraction from drawings
actor HashtagExtractor {
    /// Pure function to extract hashtags from text using regex
    /// Testable without requiring PKDrawing or Vision framework
    static func extractHashtagsFromText(_ text: String) -> Set<String> {
        let pattern = #"#(\w+)"#
        var hashtags = Set<String>()

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return hashtags
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        for match in matches {
            if let tagRange = Range(match.range(at: 1), in: text) {
                let tag = String(text[tagRange]).lowercased()
                hashtags.insert(tag)
            }
        }

        return hashtags
    }

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

        // Extract hashtags from recognized text using pure parsing function
        var hashtags = Set<String>()

        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else {
                continue
            }

            let text = topCandidate.string
            let extractedTags = Self.extractHashtagsFromText(text)
            hashtags.formUnion(extractedTags)
        }

        return hashtags
    }
}
