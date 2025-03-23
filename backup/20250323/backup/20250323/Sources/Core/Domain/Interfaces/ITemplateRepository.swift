import Foundation

public protocol ITemplateRepository {
    func create(_ template: TemplateModel) async throws
    func get(byId id: UUID) async throws -> TemplateModel
    func update(_ template: TemplateModel) async throws
    func delete(byId id: UUID) async throws
    func getAll() async throws -> [TemplateModel]
    func search(query: String) async throws -> [TemplateModel]
} 