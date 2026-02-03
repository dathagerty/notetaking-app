import XCTest
import PencilKit
@testable import NoteApp

final class HashtagExtractorTests: XCTestCase {
    // MARK: - Pure Regex Parsing Tests

    func testExtractSingleHashtag() {
        let text = "This is a note with #hashtag"
        let hashtags = HashtagExtractor.extractHashtagsFromText(text)

        XCTAssertEqual(hashtags, ["hashtag"])
    }

    func testExtractMultipleHashtags() {
        let text = "Check out #swift and #ios development with #xcode"
        let hashtags = HashtagExtractor.extractHashtagsFromText(text)

        XCTAssertEqual(hashtags, ["swift", "ios", "xcode"])
    }

    func testHashtagsAreNormalized() {
        let text = "Testing #MyTag #ALLCAPS #CamelCase"
        let hashtags = HashtagExtractor.extractHashtagsFromText(text)

        // All hashtags should be lowercased
        XCTAssertEqual(hashtags, ["mytag", "allcaps", "camelcase"])

        // Verify each hashtag is lowercase
        for hashtag in hashtags {
            XCTAssertEqual(hashtag, hashtag.lowercased())
        }
    }

    func testHashtagsDeduplicated() {
        let text = "We love #swift and #swift is great, especially #swift"
        let hashtags = HashtagExtractor.extractHashtagsFromText(text)

        // Set deduplicates hashtags
        XCTAssertEqual(hashtags, ["swift"])
        XCTAssertEqual(hashtags.count, 1)
    }

    func testNoHashtagsInText() {
        let text = "This text has no hashtags at all"
        let hashtags = HashtagExtractor.extractHashtagsFromText(text)

        XCTAssertTrue(hashtags.isEmpty)
    }

    func testHashtagWithNumbers() {
        let text = "Latest news about #ios17 #macos14 #watchos10"
        let hashtags = HashtagExtractor.extractHashtagsFromText(text)

        XCTAssertEqual(hashtags, ["ios17", "macos14", "watchos10"])
    }

    func testHashtagWithUnderscores() {
        let text = "Development tips: #best_practices #unit_testing"
        let hashtags = HashtagExtractor.extractHashtagsFromText(text)

        XCTAssertEqual(hashtags, ["best_practices", "unit_testing"])
    }

    func testHashtagAtStartOfText() {
        let text = "#swift is awesome"
        let hashtags = HashtagExtractor.extractHashtagsFromText(text)

        XCTAssertEqual(hashtags, ["swift"])
    }

    func testHashtagAtEndOfText() {
        let text = "I love coding with #swift"
        let hashtags = HashtagExtractor.extractHashtagsFromText(text)

        XCTAssertEqual(hashtags, ["swift"])
    }

    func testMultipleHashtagsInSequence() {
        let text = "Tags: #ios #swift #xcode #macos"
        let hashtags = HashtagExtractor.extractHashtagsFromText(text)

        XCTAssertEqual(hashtags, ["ios", "swift", "xcode", "macos"])
    }

    func testEmptyString() {
        let text = ""
        let hashtags = HashtagExtractor.extractHashtagsFromText(text)

        XCTAssertTrue(hashtags.isEmpty)
    }

    func testHashtagExtractionReturnsSet() {
        let text = "#tag1 #tag2"
        let hashtags = HashtagExtractor.extractHashtagsFromText(text)

        // Result should be a Set (no duplicates)
        XCTAssertTrue(type(of: hashtags) == Set<String>.self)
    }
}
