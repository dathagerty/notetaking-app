import Foundation
import SwiftData

protocol TagRepository: Sendable {
    func fetchAllTags() async throws -> [Tag]
    func fetchTag(name: String) async throws -> Tag?
    func fetchOrCreateTag(name: String) async throws -> Tag
    func fetchNotes(withTag tag: Tag) async throws -> [Note]
    func deleteTag(name: String) async throws
}

actor SwiftDataTagRepository: TagRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAllTags() async throws -> [Tag] {
        let descriptor = FetchDescriptor<Tag>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchTag(name: String) async throws -> Tag? {
        let descriptor = FetchDescriptor<Tag>(
            predicate: #Predicate { $0.name == name }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchOrCreateTag(name: String) async throws -> Tag {
        if let existing = try await fetchTag(name: name) {
            return existing
        }

        let tag = Tag(name: name)
        modelContext.insert(tag)
        try modelContext.save()
        return tag
    }

    func fetchNotes(withTag tag: Tag) async throws -> [Note] {
        let tagName = tag.name
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { note in
                note.tags?.contains { $0.name == tagName } ?? false
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func deleteTag(name: String) async throws {
        if let tag = try await fetchTag(name: name) {
            modelContext.delete(tag)
            try modelContext.save()
        }
    }
}
