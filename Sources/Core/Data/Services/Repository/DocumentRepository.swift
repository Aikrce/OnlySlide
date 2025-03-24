import Foundation
import CoreData
import os.log

public class DocumentRepository: IDocumentRepository {
    private let context: NSManagedObjectContext
    private let logger: os.log
    
    public init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext,
                logger: os.log = os.log(subsystem: "com.onlyslide.repository.document", category: .pointsOfInterest)) {
        self.context = context
        self.logger = logger
    }
    
    public func create(_ document: Document) async throws {
        do {
            let entity = DocumentEntity(context: context)
            entity.documentModel = document
            
            try context.save()
            logger.info("Created document with ID: \(document.id)")
        } catch {
            logger.error("Failed to create document: \(error)")
            throw CoreDataError.saveFailed(error)
        }
    }
    
    public func get(by id: UUID) async throws -> Document {
        let fetchRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1
        
        do {
            guard let entity = try context.fetch(fetchRequest).first else {
                logger.warning("Document not found with ID: \(id)")
                throw CoreDataError.notFound
            }
            return entity.documentModel
        } catch {
            logger.error("Failed to fetch document: \(error)")
            throw CoreDataError.fetchFailed(error)
        }
    }
    
    public func update(_ document: Document) async throws -> Document {
        do {
            let fetchRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", document.id as CVarArg)
            fetchRequest.fetchLimit = 1
            
            guard let entity = try context.fetch(fetchRequest).first else {
                logger.warning("Document not found for update with ID: \(document.id)")
                throw CoreDataError.notFound
            }
            
            entity.documentModel = document
            try context.save()
            logger.info("Updated document with ID: \(document.id)")
            return entity.documentModel
        } catch {
            logger.error("Failed to update document: \(error)")
            throw CoreDataError.updateFailed(error)
        }
    }
    
    public func delete(by id: UUID) async throws {
        do {
            let fetchRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1
            
            guard let entity = try context.fetch(fetchRequest).first else {
                logger.warning("Document not found for deletion with ID: \(id)")
                throw CoreDataError.notFound
            }
            
            context.delete(entity)
            try context.save()
            logger.info("Deleted document with ID: \(id)")
        } catch {
            logger.error("Failed to delete document: \(error)")
            throw CoreDataError.deleteFailed(error)
        }
    }
    
    public func getAll() async throws -> [Document] {
        let fetchRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        
        do {
            let entities = try context.fetch(fetchRequest)
            let documents = entities.map { $0.documentModel }
            logger.info("Fetched \(documents.count) documents")
            return documents
        } catch {
            logger.error("Failed to fetch all documents: \(error)")
            throw CoreDataError.fetchFailed(error)
        }
    }
    
    public func search(query: String) async throws -> [Document] {
        let fetchRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "title CONTAINS[cd] %@ OR content CONTAINS[cd] %@",
            query, query
        )
        
        do {
            let entities = try context.fetch(fetchRequest)
            let documents = entities.map { $0.documentModel }
            logger.info("Found \(documents.count) documents matching query: \(query)")
            return documents
        } catch {
            logger.error("Failed to search documents: \(error)")
            throw CoreDataError.fetchFailed(error)
        }
    }
} 