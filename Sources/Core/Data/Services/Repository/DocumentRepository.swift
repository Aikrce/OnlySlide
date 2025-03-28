import Foundation
import CoreData
import os.log
import CoreDataModule

public protocol IDocumentRepository {
    func create(_ document: Document) async throws
    func get(by id: UUID) async throws -> Document
    func update(_ document: Document) async throws -> Document
    func delete(by id: UUID) async throws
    func getAll() async throws -> [Document]
    func search(query: String) async throws -> [Document]
}

public class DocumentRepository: IDocumentRepository {
    private let context: NSManagedObjectContext
    private let logger: os.log
    private let repository: CoreDataRepository<CDDocument>
    
    public init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext,
                logger: os.log = os.log(subsystem: "com.onlyslide.repository.document", category: .pointsOfInterest)) {
        self.context = context
        self.logger = logger
        self.repository = CoreDataRepository<CDDocument>(context: context)
    }
    
    public func create(_ document: Document) async throws {
        do {
            let entity = CDDocument(context: context)
            entity.update(from: document)
            
            try context.save()
            logger.info("Created document with ID: \(document.id)")
        } catch {
            logger.error("Failed to create document: \(error)")
            throw CoreDataError.saveFailed(error)
        }
    }
    
    public func get(by id: UUID) async throws -> Document {
        do {
            let predicate = NSPredicate(format: "id == %@", id as CVarArg)
            guard let document = try repository.fetchOneDomain(predicate: predicate) else {
                logger.warning("Document not found with ID: \(id)")
                throw CoreDataError.notFound("Document with ID \(id)")
            }
            return document
        } catch let error as CoreDataError {
            throw error
        } catch {
            logger.error("Failed to fetch document: \(error)")
            throw CoreDataError.fetchFailed(error)
        }
    }
    
    public func update(_ document: Document) async throws -> Document {
        do {
            let predicate = NSPredicate(format: "id == %@", document.id as CVarArg)
            guard let entity = try repository.fetchOne(predicate: predicate) else {
                logger.warning("Document not found for update with ID: \(document.id)")
                throw CoreDataError.notFound("Document with ID \(document.id)")
            }
            
            entity.update(from: document)
            try repository.update(entity)
            
            logger.info("Updated document with ID: \(document.id)")
            return entity.toDomain()
        } catch let error as CoreDataError {
            throw error
        } catch {
            logger.error("Failed to update document: \(error)")
            throw CoreDataError.updateFailed(error)
        }
    }
    
    public func delete(by id: UUID) async throws {
        do {
            let predicate = NSPredicate(format: "id == %@", id as CVarArg)
            guard let entity = try repository.fetchOne(predicate: predicate) else {
                logger.warning("Document not found for deletion with ID: \(id)")
                throw CoreDataError.notFound("Document with ID \(id)")
            }
            
            try repository.delete(entity)
            logger.info("Deleted document with ID: \(id)")
        } catch let error as CoreDataError {
            throw error
        } catch {
            logger.error("Failed to delete document: \(error)")
            throw CoreDataError.deleteFailed(error)
        }
    }
    
    public func getAll() async throws -> [Document] {
        do {
            let documents = try repository.fetchDomain()
            logger.info("Fetched \(documents.count) documents")
            return documents
        } catch {
            logger.error("Failed to fetch all documents: \(error)")
            throw CoreDataError.fetchFailed(error)
        }
    }
    
    public func search(query: String) async throws -> [Document] {
        do {
            let predicate = NSPredicate(
                format: "title CONTAINS[cd] %@ OR content CONTAINS[cd] %@",
                query, query
            )
            let documents = try repository.fetchDomain(predicate: predicate)
            logger.info("Found \(documents.count) documents matching query: \(query)")
            return documents
        } catch {
            logger.error("Failed to search documents: \(error)")
            throw CoreDataError.fetchFailed(error)
        }
    }
    
    // MARK: - 线程安全方法
    
    /// 执行后台操作
    /// - Parameter operation: 后台操作
    /// - Returns: 操作结果
    public func performBackgroundOperation<T>(_ operation: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            repository.performAsync(operation) { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
} 