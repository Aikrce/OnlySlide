import CoreData
import Foundation
import Logging

protocol IDocumentPersistence {
    func fetchDocuments(for user: User) -> [Document]
    func fetchRecentDocuments(limit: Int) -> [Document]
    func fetchDocuments(withType type: String) -> [Document]
    func searchDocuments(keyword: String) -> [Document]
}

final class CoreDataDocumentRepository: CoreDataRepository<Document> {
    private let logger = Logger(label: "com.onlyslide.repository.coredatadocument")
    
    // MARK: - Initialization
    override init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        super.init(context: context)
    }
    
    // MARK: - Fetch Operations
    
    func fetchDocuments(for user: User) -> [Document] {
        let predicate = NSPredicate(format: "owner == %@ OR ANY collaborators == %@", user, user)
        return fetch(predicate: predicate)
    }
    
    func fetchRecentDocuments(limit: Int) -> [Document] {
        let request = Document.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        request.fetchLimit = limit
        
        do {
            return try CoreDataStack.shared.viewContext.fetch(request) as? [Document] ?? []
        } catch {
            print("获取最近文档失败: \(error)")
            return []
        }
    }
    
    func fetchDocuments(withType type: String) -> [Document] {
        let predicate = NSPredicate(format: "type == %@", type)
        return fetch(predicate: predicate)
    }
    
    func searchDocuments(keyword: String) -> [Document] {
        let predicate = NSPredicate(format: "title CONTAINS[cd] %@ OR ANY tags CONTAINS[cd] %@", keyword, keyword)
        return fetch(predicate: predicate)
    }
    
    // MARK: - IDocumentRepository Implementation
    
    func create(_ document: Document) async throws {
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
    
    func get(by id: UUID) async throws -> Document {
        let request = DocumentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            guard let entity = try context.fetch(request).first else {
                logger.warning("Document not found with ID: \(id)")
                throw CoreDataError.notFound
            }
            return entity.documentModel
        } catch {
            logger.error("Failed to fetch document: \(error)")
            throw CoreDataError.fetchFailed(error)
        }
    }
    
    func update(_ document: Document) async throws -> Document {
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
            throw CoreDataError.saveFailed(error)
        }
    }
    
    func delete(by id: UUID) async throws {
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
    
    func getAll() async throws -> [Document] {
        let request = DocumentEntity.fetchRequest()
        
        do {
            let entities = try context.fetch(request)
            let documents = entities.map { $0.documentModel }
            logger.info("Fetched \(documents.count) documents")
            return documents
        } catch {
            logger.error("Failed to fetch documents: \(error)")
            throw CoreDataError.fetchFailed(error)
        }
    }
    
    func search(query: String) async throws -> [Document] {
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
    
    // MARK: - Advanced Operations
    
    /// 复制文档
    /// - Parameters:
    ///   - document: 要复制的文档
    ///   - newTitle: 新文档标题
    ///   - newOwner: 新文档所有者
    /// - Returns: 复制的新文档
    func duplicate(_ document: Document, withTitle newTitle: String, owner newOwner: User) -> Document {
        let newDocument = create()
        
        // 复制基本属性
        newDocument.title = newTitle
        newDocument.type = document.type
        newDocument.content = document.content
        newDocument.metadata = document.metadata
        newDocument.tags = document.tags
        newDocument.template = document.template
        newDocument.owner = newOwner
        newDocument.createdAt = Date()
        newDocument.updatedAt = Date()
        
        // 复制幻灯片
        if let slides = document.slides {
            for slide in Array(slides) {
                let newSlide = Slide(context: CoreDataStack.shared.viewContext)
                newSlide.title = slide.title
                newSlide.content = slide.content
                newSlide.index = slide.index
                newSlide.document = newDocument
                
                // 复制元素
                if let elements = slide.elements {
                    for element in Array(elements) {
                        let newElement = Element(context: CoreDataStack.shared.viewContext)
                        newElement.content = element.content
                        newElement.position = element.position
                        newElement.dimensions = element.dimensions
                        newElement.style = element.style
                        newElement.slide = newSlide
                    }
                }
            }
        }
        
        CoreDataStack.shared.saveViewContext()
        return newDocument
    }
    
    /// 归档文档
    /// - Parameter document: 要归档的文档
    func archive(_ document: Document) {
        document.processingStatus = 2 // 假设 2 表示已归档状态
        update(document)
    }
    
    /// 恢复归档的文档
    /// - Parameter document: 要恢复的文档
    func unarchive(_ document: Document) {
        document.processingStatus = 0 // 假设 0 表示正常状态
        update(document)
    }
    
    /// 添加协作者
    /// - Parameters:
    ///   - document: 目标文档
    ///   - collaborator: 要添加的协作者
    func addCollaborator(_ collaborator: User, to document: Document) {
        document.addToCollaborators(collaborator)
        update(document)
    }
    
    /// 移除协作者
    /// - Parameters:
    ///   - document: 目标文档
    ///   - collaborator: 要移除的协作者
    func removeCollaborator(_ collaborator: User, from document: Document) {
        document.removeFromCollaborators(collaborator)
        update(document)
    }
    
    // MARK: - Private Methods
    private func fetchDocument(by id: UUID) throws -> Document? {
        let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1
        
        return try context.fetch(fetchRequest).first
    }
    
    private func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }
}

// MARK: - IDocumentRepository Implementation
extension CoreDataDocumentRepository: IDocumentRepository {
    func copy(_ document: Document) async throws -> Document {
        let newDocument = Document(context: context)
        
        // 复制基本属性
        newDocument.id = UUID()
        newDocument.title = document.title
        newDocument.content = document.content
        newDocument.createdAt = Date()
        newDocument.updatedAt = Date()
        newDocument.metadata = document.metadata
        newDocument.processingStatus = document.processingStatus
        newDocument.sourceURL = document.sourceURL
        
        // 复制幻灯片
        if let slides = document.slides {
            for slide in Array(slides) {
                let newSlide = Slide(context: CoreDataStack.shared.viewContext)
                newSlide.title = slide.title
                newSlide.content = slide.content
                newSlide.index = slide.index
                newSlide.document = newDocument
                
                // 复制元素
                if let elements = slide.elements {
                    for element in Array(elements) {
                        let newElement = Element(context: CoreDataStack.shared.viewContext)
                        newElement.content = element.content
                        newElement.position = element.position
                        newElement.dimensions = element.dimensions
                        newElement.style = element.style
                        newElement.slide = newSlide
                    }
                }
            }
        }
        
        try save()
        return newDocument
    }
} 