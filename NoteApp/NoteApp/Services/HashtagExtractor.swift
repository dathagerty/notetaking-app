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
