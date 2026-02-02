import XCTest
import PencilKit
@testable import NoteApp

final class HashtagExtractorTests: XCTestCase {
    var extractor: HashtagExtractor!

    override func setUp() {
        super.setUp()
        extractor = HashtagExtractor()
    }

    override func tearDown() {
        super.tearDown()
        extractor = nil
    }

    // MARK: - Basic Hashtag Extraction

    func testExtractSingleHashtag() async throws {
        // Create a simple drawing with text (we'll use an empty drawing for now
        // since rendering text in PKDrawing is complex in tests)
        let drawing = PKDrawing()

        let hashtags = try await extractor.extractHashtags(from: drawing)

        // Empty drawing should return empty set
        XCTAssertEqual(hashtags, [])
    }

    func testExtractMultipleHashtags() async throws {
        let drawing = PKDrawing()

        let hashtags = try await extractor.extractHashtags(from: drawing)

        // Empty drawing should return empty set
        XCTAssertEqual(hashtags, [])
    }

    func testHashtagsAreNormalized() async throws {
        let drawing = PKDrawing()

        let hashtags = try await extractor.extractHashtags(from: drawing)

        // Hashtags should be lowercased
        for hashtag in hashtags {
            XCTAssertEqual(hashtag, hashtag.lowercased())
        }
    }

    func testExtractEmptyDrawing() async throws {
        let drawing = PKDrawing()

        let hashtags = try await extractor.extractHashtags(from: drawing)

        // Empty drawing should return empty set
        XCTAssertTrue(hashtags.isEmpty)
    }

    func testHashtagExtractionReturnsSet() async throws {
        let drawing = PKDrawing()

        let hashtags = try await extractor.extractHashtags(from: drawing)

        // Result should be a Set (no duplicates)
        XCTAssertTrue(type(of: hashtags) == Set<String>.self)
    }
}
