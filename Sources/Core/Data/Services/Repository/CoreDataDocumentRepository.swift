import CoreData
import Foundation
import os.log
import Combine
import CoreDataModule

protocol IDocumentPersistence {
    func fetchDocuments(for user: CDUser) -> [CDDocument]
    func fetchRecentDocuments(limit: Int) -> [CDDocument]
    func fetchDocuments(withType type: String) -> [CDDocument]
    func searchDocuments(keyword: String) -> [CDDocument]
}

final class CoreDataDocumentRepository: CoreDataRepository<CDDocument> {
    private let logger = Logger(label: "com.onlyslide.repository.coredatadocument")
    
    // MARK: - Properties
    
    private let coreDataManager: CoreDataManager
    private let syncManager: CoreDataSyncManager
    private let conflictResolver: CoreDataConflictResolver
    private let documentCache: DocumentCache
    
    private let documentChangeSubject = PassthroughSubject<DocumentChangeEvent, Never>()
    private var documentChangePublisher: AnyPublisher<DocumentChangeEvent, Never> {
        return documentChangeSubject.eraseToAnyPublisher()
    }
    
    private var documentObservers: [UUID: PassthroughSubject<DocumentChangeEvent, Never>] = [:]
    
    // MARK: - Initialization
    
    init(
        coreDataManager: CoreDataManager = CoreDataManager.shared,
        syncManager: CoreDataSyncManager = CoreDataSyncManager.shared,
        conflictResolver: CoreDataConflictResolver = CoreDataConflictResolver.shared,
        documentCache: DocumentCache = DocumentCache.shared
    ) {
        self.coreDataManager = coreDataManager
        self.syncManager = syncManager
        self.conflictResolver = conflictResolver
        self.documentCache = documentCache
        
        // 设置通知观察者
        super.init(context: CoreDataStack.shared.viewContext)
        
        setupNotificationObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Fetch Operations
    
    func fetchDocuments(for user: CDUser) -> [CDDocument] {
        do {
            let predicate = NSPredicate(format: "owner == %@ OR ANY collaborators == %@", user, user)
            return try fetch(predicate: predicate)
        } catch {
            logger.error("Failed to fetch documents for user: \(error)")
            return []
        }
    }
    
    func fetchRecentDocuments(limit: Int) -> [CDDocument] {
        do {
            let request = CDDocument.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
            request.fetchLimit = limit
            
            return try context.fetch(request) as? [CDDocument] ?? []
        } catch {
            logger.error("Failed to fetch recent documents: \(error)")
            return []
        }
    }
    
    func fetchDocuments(withType type: String) -> [CDDocument] {
        do {
            let predicate = NSPredicate(format: "type == %@", type)
            return try fetch(predicate: predicate)
        } catch {
            logger.error("Failed to fetch documents with type: \(error)")
            return []
        }
    }
    
    func searchDocuments(keyword: String) -> [CDDocument] {
        do {
            let predicate = NSPredicate(format: "title CONTAINS[cd] %@ OR ANY tags CONTAINS[cd] %@", keyword, keyword)
            return try fetch(predicate: predicate)
        } catch {
            logger.error("Failed to search documents: \(error)")
            return []
        }
    }
    
    // MARK: - IDocumentRepository Implementation
    
    func create(_ document: Document) async throws -> CDDocument {
        return try await performBackgroundOperation { context in
            do {
                let entity = CDDocument(context: context)
                entity.update(from: document)
                
                try context.save()
                self.documentCache.cacheDocument(entity.toDomain())
                
                return entity
            } catch {
                throw CoreDataError.saveFailed(error)
            }
        }
    }
    
    func get(by id: UUID) async throws -> CDDocument {
        // 尝试从缓存获取
        if let cachedDocument = documentCache.getDocument(id: id) {
            // 转换为CDDocument
            if let entity = CDDocument.find(byID: id, in: context) {
                return entity
            }
        }
        
        return try await performBackgroundOperation { context in
            let predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            let request = CDDocument.fetchRequest()
            request.predicate = predicate
            request.fetchLimit = 1
            
            guard let document = try context.fetch(request).first else {
                throw CoreDataError.notFound("Document with ID \(id)")
            }
            
            return document
        }
    }
    
    func update(_ document: CDDocument) async throws -> CDDocument {
        return try await performBackgroundOperation { context in
            // 获取对象ID
            let objectID = document.objectID
            
            // 在后台上下文中查找对象
            guard let backgroundEntity = context.object(with: objectID) as? CDDocument else {
                throw CoreDataError.notFound("Document with ID \(document.id)")
            }
            
            // 更新实体属性
            backgroundEntity.title = document.title
            backgroundEntity.content = document.content
            backgroundEntity.type = document.type
            backgroundEntity.tags = document.tags
            backgroundEntity.metadata = document.metadata
            backgroundEntity.updatedAt = Date()
            
            // 保存上下文
            try context.save()
            
            // 更新缓存
            self.documentCache.cacheDocument(backgroundEntity.toDomain())
            
            return backgroundEntity
        }
    }
    
    func delete(by id: UUID) async throws {
        try await performBackgroundOperation { context in
            // 查找文档
            let request = CDDocument.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            
            guard let document = try context.fetch(request).first else {
                throw CoreDataError.notFound("Document with ID \(id)")
            }
            
            // 删除文档
            context.delete(document)
            
            // 保存上下文
            try context.save()
            
            // 移除缓存
            self.documentCache.invalidateDocument(id: id)
        }
    }
    
    func getAll() async throws -> [CDDocument] {
        return try await performBackgroundOperation { context in
            let request = CDDocument.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
            
            let documents = try context.fetch(request)
            
            // 更新缓存
            self.documentCache.cacheDocuments(documents.map { $0.toDomain() })
            
            return documents
        }
    }
    
    func search(query: String) async throws -> [CDDocument] {
        return try await performBackgroundOperation { context in
            let predicate = NSPredicate(
                format: "title CONTAINS[cd] %@ OR content CONTAINS[cd] %@",
                query, query
            )
            
            let request = CDDocument.fetchRequest()
            request.predicate = predicate
            
            return try context.fetch(request)
        }
    }
    
    // MARK: - Advanced Operations
    
    /// 复制文档
    /// - Parameters:
    ///   - document: 要复制的文档
    ///   - newTitle: 新文档标题
    ///   - newOwner: 新文档所有者
    /// - Returns: 复制的新文档
    func duplicate(_ document: CDDocument, withTitle newTitle: String, owner newOwner: CDUser) throws -> CDDocument {
        return try performBackgroundOperation { context in
            // 获取原文档的管理对象ID
            let documentID = document.objectID
            let ownerID = newOwner.objectID
            
            // 在后台上下文中获取对象
            guard let originalDocument = context.object(with: documentID) as? CDDocument,
                  let owner = context.object(with: ownerID) as? CDUser else {
                throw CoreDataError.notFound("Original document or owner not found")
            }
            
            // 创建新文档
            let newDocument = CDDocument(context: context)
            
            // 复制基本属性
            newDocument.title = newTitle
            newDocument.type = originalDocument.type
            newDocument.content = originalDocument.content
            newDocument.metadata = originalDocument.metadata
            newDocument.tags = originalDocument.tags
            newDocument.template = originalDocument.template
            newDocument.owner = owner
            newDocument.createdAt = Date()
            newDocument.updatedAt = Date()
            
            // 复制幻灯片
            if let slides = originalDocument.slides {
                for slide in Array(slides) {
                    let slideID = slide.objectID
                    guard let originalSlide = context.object(with: slideID) as? CDSlide else {
                        continue
                    }
                    
                    let newSlide = CDSlide(context: context)
                    newSlide.title = originalSlide.title
                    newSlide.content = originalSlide.content
                    newSlide.index = originalSlide.index
                    newSlide.document = newDocument
                    
                    // 复制元素
                    if let elements = originalSlide.elements {
                        for element in Array(elements) {
                            let elementID = element.objectID
                            guard let originalElement = context.object(with: elementID) as? CDElement else {
                                continue
                            }
                            
                            let newElement = CDElement(context: context)
                            newElement.content = originalElement.content
                            newElement.position = originalElement.position
                            newElement.dimensions = originalElement.dimensions
                            newElement.style = originalElement.style
                            newElement.slide = newSlide
                        }
                    }
                }
            }
            
            // 保存上下文
            try context.save()
            
            // 更新缓存
            self.documentCache.cacheDocument(newDocument.toDomain())
            
            return newDocument
        } as! CDDocument
    }
    
    /// 归档文档
    /// - Parameter document: 要归档的文档
    func archive(_ document: CDDocument) throws {
        try performBackgroundOperation { context in
            // 获取文档管理对象ID
            let documentID = document.objectID
            
            // 在后台上下文中获取对象
            guard let documentToArchive = context.object(with: documentID) as? CDDocument else {
                throw CoreDataError.notFound("Document not found")
            }
            
            // 设置归档状态
            documentToArchive.processingStatus = 2 // 假设 2 表示已归档状态
            
            // 保存上下文
            try context.save()
            
            // 更新缓存
            self.documentCache.cacheDocument(documentToArchive.toDomain())
        }
    }
    
    /// 恢复归档的文档
    /// - Parameter document: 要恢复的文档
    func unarchive(_ document: CDDocument) throws {
        try performBackgroundOperation { context in
            // 获取文档管理对象ID
            let documentID = document.objectID
            
            // 在后台上下文中获取对象
            guard let documentToUnarchive = context.object(with: documentID) as? CDDocument else {
                throw CoreDataError.notFound("Document not found")
            }
            
            // 设置正常状态
            documentToUnarchive.processingStatus = 0 // 假设 0 表示正常状态
            
            // 保存上下文
            try context.save()
            
            // 更新缓存
            self.documentCache.cacheDocument(documentToUnarchive.toDomain())
        }
    }
    
    /// 添加协作者
    /// - Parameters:
    ///   - document: 目标文档
    ///   - collaborator: 要添加的协作者
    func addCollaborator(_ collaborator: CDUser, to document: CDDocument) throws {
        try performBackgroundOperation { context in
            // 获取对象ID
            let documentID = document.objectID
            let collaboratorID = collaborator.objectID
            
            // 在后台上下文中获取对象
            guard let documentToUpdate = context.object(with: documentID) as? CDDocument,
                  let collaboratorToAdd = context.object(with: collaboratorID) as? CDUser else {
                throw CoreDataError.notFound("Document or collaborator not found")
            }
            
            // 添加协作者
            documentToUpdate.addToCollaborators(collaboratorToAdd)
            
            // 保存上下文
            try context.save()
            
            // 更新缓存
            self.documentCache.cacheDocument(documentToUpdate.toDomain())
        }
    }
    
    /// 移除协作者
    /// - Parameters:
    ///   - document: 目标文档
    ///   - collaborator: 要移除的协作者
    func removeCollaborator(_ collaborator: CDUser, from document: CDDocument) throws {
        try performBackgroundOperation { context in
            // 获取对象ID
            let documentID = document.objectID
            let collaboratorID = collaborator.objectID
            
            // 在后台上下文中获取对象
            guard let documentToUpdate = context.object(with: documentID) as? CDDocument,
                  let collaboratorToRemove = context.object(with: collaboratorID) as? CDUser else {
                throw CoreDataError.notFound("Document or collaborator not found")
            }
            
            // 移除协作者
            documentToUpdate.removeFromCollaborators(collaboratorToRemove)
            
            // 保存上下文
            try context.save()
            
            // 更新缓存
            self.documentCache.cacheDocument(documentToUpdate.toDomain())
        }
    }
    
    // MARK: - Private Methods
    
    /// 在后台上下文中执行操作
    /// - Parameter operation: 要执行的操作
    /// - Returns: 操作结果
    private func performBackgroundOperation<T>(_ operation: @escaping (NSManagedObjectContext) throws -> T) throws -> T {
        let backgroundContext = coreDataManager.newBackgroundContext()
        
        var result: T?
        var operationError: Error?
        
        let semaphore = DispatchSemaphore(value: 0)
        
        backgroundContext.perform {
            do {
                result = try operation(backgroundContext)
            } catch {
                operationError = error
            }
            
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = operationError {
            throw error
        }
        
        return result!
    }
    
    /// 异步执行后台操作
    /// - Parameter operation: 要执行的操作
    /// - Returns: 操作结果
    private func performBackgroundOperation<T>(_ operation: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            let backgroundContext = coreDataManager.newBackgroundContext()
            
            backgroundContext.perform {
                do {
                    let result = try operation(backgroundContext)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func setupNotificationObservers() {
        // 观察 Core Data 上下文保存通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(managedObjectContextDidSave(_:)),
            name: .NSManagedObjectContextDidSave,
            object: nil
        )
    }
    
    @objc private func managedObjectContextDidSave(_ notification: Notification) {
        let context = notification.object as? NSManagedObjectContext
        
        // 忽略主上下文发出的通知，因为我们已经手动处理了这些
        if context == coreDataManager.mainContext {
            return
        }
        
        // 处理插入的文档
        if let insertedObjects = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> {
            handleChangedObjects(insertedObjects, changeType: .added)
        }
        
        // 处理更新的文档
        if let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> {
            handleChangedObjects(updatedObjects, changeType: .updated)
        }
        
        // 处理删除的文档
        if let deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> {
            for object in deletedObjects {
                if object.entity.name == "CDDocument",
                   let idValue = object.value(forKey: "id") as? UUID {
                    DispatchQueue.main.async {
                        self.documentChangeSubject.send(.deleted(idValue))
                        
                        if let subject = self.documentObservers[idValue] {
                            subject.send(.deleted(idValue))
                        }
                    }
                }
            }
        }
    }
    
    private func handleChangedObjects(_ objects: Set<NSManagedObject>, changeType: (CDDocument) -> DocumentChangeEvent) {
        for object in objects {
            guard object.entity.name == "CDDocument" else { continue }
            
            // 在主上下文中获取对象
            let mainContext = coreDataManager.mainContext
            let objectID = object.objectID
            
            mainContext.perform {
                guard let mainObject = mainContext.object(with: objectID) as? CDDocument,
                      let documentId = mainObject.value(forKey: "id") as? UUID else { return }
                
                DispatchQueue.main.async {
                    self.documentChangeSubject.send(changeType(mainObject))
                    
                    if let subject = self.documentObservers[documentId] {
                        subject.send(changeType(mainObject))
                    }
                }
            }
        }
    }
}

// MARK: - IDocumentRepository Implementation
extension CoreDataDocumentRepository: IDocumentRepository {
    func getAllDocuments() async throws -> [CDDocument] {
        let request = DocumentEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        
        do {
            let entities = try context.fetch(request)
            let documents = entities.map { $0.documentModel }
            
            // 更新缓存
            documentCache.cacheDocuments(documents)
            
            logger.info("Fetched \(documents.count) documents")
            return documents
        } catch {
            logger.error("Failed to fetch all documents: \(error)")
            throw CoreDataError.fetchFailed(error)
        }
    }
    
    func getDocument(id: UUID) async throws -> CDDocument? {
        // 尝试从缓存获取
        if let cachedDocument = documentCache.getDocument(id: id) {
            logger.info("Retrieved document from cache: \(id)")
            return cachedDocument
        }
        
        // 缓存未命中，从数据库获取
        let request = DocumentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            guard let entity = try context.fetch(request).first else {
                logger.info("Document not found with ID: \(id)")
                return nil
            }
            
            let document = entity.documentModel
            
            // 更新缓存
            documentCache.cacheDocument(document)
            
            return document
        } catch {
            logger.error("Failed to fetch document: \(error)")
            throw CoreDataError.fetchFailed(error)
        }
    }
    
    func createDocument(_ document: CDDocument) async throws -> CDDocument {
        do {
            let entity = DocumentEntity(context: context)
            entity.documentModel = document
            try context.save()
            
            let createdDocument = entity.documentModel
            
            // 更新缓存
            documentCache.cacheDocument(createdDocument)
            
            // 发送通知
            documentChangeSubject.send(.added(createdDocument))
            
            logger.info("Created document with ID: \(document.id)")
            return createdDocument
        } catch {
            logger.error("Failed to create document: \(error)")
            throw CoreDataError.saveFailed(error)
        }
    }
    
    func updateDocument(_ document: CDDocument) async throws -> CDDocument {
        do {
            let request = DocumentEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", document.id as CVarArg)
            request.fetchLimit = 1
            
            guard let entity = try context.fetch(request).first else {
                logger.warning("Document not found for update with ID: \(document.id)")
                throw CoreDataError.notFound
            }
            
            entity.documentModel = document
            try context.save()
            
            let updatedDocument = entity.documentModel
            
            // 更新缓存
            documentCache.cacheDocument(updatedDocument)
            
            // 发送通知
            documentChangeSubject.send(.updated(updatedDocument))
            
            logger.info("Updated document with ID: \(document.id)")
            return updatedDocument
        } catch {
            logger.error("Failed to update document: \(error)")
            throw CoreDataError.saveFailed(error)
        }
    }
    
    func deleteDocument(id: UUID) async throws {
        do {
            let request = DocumentEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            
            guard let entity = try context.fetch(request).first else {
                logger.warning("Document not found for deletion with ID: \(id)")
                throw CoreDataError.notFound
            }
            
            context.delete(entity)
            try context.save()
            
            // 移除缓存
            documentCache.invalidateDocument(id: id)
            
            // 发送通知
            documentChangeSubject.send(.deleted(id))
            
            logger.info("Deleted document with ID: \(id)")
        } catch {
            logger.error("Failed to delete document: \(error)")
            throw CoreDataError.deleteFailed(error)
        }
    }
    
    func searchDocuments(query: DocumentSearchQuery) async throws -> [CDDocument] {
        // 如果查询仅包含标签，尝试从缓存获取
        if let tags = query.text?.components(separatedBy: " ").filter({ $0.hasPrefix("#") }).map({ String($0.dropFirst()) }),
           !tags.isEmpty && query.types == nil && query.dateRange == nil {
            
            var cachedResults: [CDDocument] = []
            var allTagIds = Set<UUID>()
            var firstTag = true
            
            // 计算包含所有标签的文档ID
            for tag in tags {
                let tagIds = documentCache.getDocumentIds(forTag: tag)
                if firstTag {
                    allTagIds = tagIds
                    firstTag = false
                } else {
                    allTagIds = allTagIds.intersection(tagIds)
                }
            }
            
            // 如果找到缓存的ID，获取文档
            if !allTagIds.isEmpty {
                cachedResults = documentCache.getDocuments(ids: Array(allTagIds))
                if cachedResults.count == allTagIds.count {
                    // 所有文档都在缓存中，直接返回
                    logger.info("从缓存获取 \(cachedResults.count) 个标签搜索结果")
                    return cachedResults
                }
            }
        }
        
        // 缓存未命中或不适用于此查询，执行数据库查询
        var predicates: [NSPredicate] = []
        
        // 添加文本搜索条件
        if let searchText = query.text {
            predicates.append(NSPredicate(
                format: "title CONTAINS[cd] %@ OR content CONTAINS[cd] %@",
                searchText, searchText
            ))
        }
        
        // 添加类型过滤条件
        if let types = query.types, !types.isEmpty {
            let typeValues = types.map { $0.rawValue }
            predicates.append(NSPredicate(format: "type IN %@", typeValues))
        }
        
        // 添加日期范围条件
        if let dateRange = query.dateRange {
            predicates.append(NSPredicate(
                format: "createdAt >= %@ AND createdAt < %@",
                dateRange.lowerBound as NSDate,
                dateRange.upperBound as NSDate
            ))
        }
        
        let request = DocumentEntity.fetchRequest()
        request.predicate = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        // 添加排序
        let sortDescriptor = NSSortDescriptor(
            key: sortFieldKey(for: query.sortBy),
            ascending: query.sortOrder == .ascending
        )
        request.sortDescriptors = [sortDescriptor]
        
        do {
            let entities = try context.fetch(request)
            let documents = entities.map { $0.documentModel }
            
            // 更新缓存
            documentCache.cacheDocuments(documents)
            
            logger.info("Found \(documents.count) documents matching search query")
            return documents
        } catch {
            logger.error("Failed to search documents: \(error)")
            throw CoreDataError.fetchFailed(error)
        }
    }
    
    func getDocumentsByTags(_ tags: [String]) async throws -> [CDDocument] {
        // 尝试从缓存获取
        if !tags.isEmpty {
            var cachedResults: [CDDocument] = []
            var allTagIds = Set<UUID>()
            var firstTag = true
            
            // 计算包含所有标签的文档ID
            for tag in tags {
                let tagIds = documentCache.getDocumentIds(forTag: tag)
                if firstTag {
                    allTagIds = tagIds
                    firstTag = false
                } else {
                    allTagIds = allTagIds.intersection(tagIds)
                }
            }
            
            // 如果找到缓存的ID，获取文档
            if !allTagIds.isEmpty {
                cachedResults = documentCache.getDocuments(ids: Array(allTagIds))
                if cachedResults.count == allTagIds.count {
                    // 所有文档都在缓存中，直接返回
                    logger.info("从缓存获取 \(cachedResults.count) 个标签文档")
                    return cachedResults
                }
            }
        }
        
        // 缓存未命中，从数据库获取
        let request = DocumentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "ANY tags IN %@", tags)
        
        do {
            let entities = try context.fetch(request)
            let documents = entities.map { $0.documentModel }
            
            // 更新缓存
            documentCache.cacheDocuments(documents)
            
            logger.info("Found \(documents.count) documents with specified tags")
            return documents
        } catch {
            logger.error("Failed to fetch documents by tags: \(error)")
            throw CoreDataError.fetchFailed(error)
        }
    }
    
    func syncDocuments() async throws -> [CDDocument] {
        do {
            // 开始同步
            syncManager.syncState = .syncing
            
            // 获取所有需要同步的文档
            let documentsToSync = try await getAllDocuments()
            
            // 执行同步操作
            let syncedDocuments = try await syncManager.syncDocuments(documentsToSync)
            
            // 更新同步状态
            syncManager.syncState = .completed
            
            // 更新缓存
            documentCache.cacheDocuments(syncedDocuments)
            
            // 通知观察者刷新
            documentChangeSubject.send(.refreshed(syncedDocuments))
            
            logger.info("Successfully synced \(syncedDocuments.count) documents")
            return syncedDocuments
        } catch {
            syncManager.syncState = .error(error)
            logger.error("Failed to sync documents: \(error)")
            throw error
        }
    }
    
    var syncState: SyncState {
        get async {
            return syncManager.syncState
        }
    }
    
    func resolveConflict(document: CDDocument, resolution: ConflictResolution) async throws -> CDDocument {
        do {
            let strategy: CoreDataConflictResolver.ConflictResolutionStrategy
            
            switch resolution {
            case .keepLocal:
                strategy = .localWins
            case .useRemote:
                strategy = .serverWins
            case .merge:
                strategy = .merge
            case .custom(let customDocument):
                // 对于自定义合并，我们直接使用提供的文档
                return try await updateDocument(customDocument)
            }
            
            // 获取服务器数据
            let serverData = try await syncManager.fetchServerData(for: document.id)
            
            // 解决冲突
            let resolvedDocument = try conflictResolver.resolveConflict(
                localObject: document as! NSManagedObject,
                serverData: serverData,
                strategy: strategy,
                context: context
            )
            
            // 保存并返回解决后的文档
            try context.save()
            logger.info("Resolved conflict for document: \(document.id)")
            
            return resolvedDocument as! CDDocument
        } catch {
            logger.error("Failed to resolve conflict: \(error)")
            throw error
        }
    }
    
    func observeDocuments() -> AnyPublisher<DocumentChangeEvent, Never> {
        return documentChangePublisher
    }
    
    func observeDocument(id: UUID) -> AnyPublisher<DocumentChangeEvent, Never> {
        let subject = documentObservers[id] ?? PassthroughSubject<DocumentChangeEvent, Never>()
        documentObservers[id] = subject
        return subject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Helpers
    
    private func sortFieldKey(for field: DocumentSortField) -> String {
        switch field {
        case .title:
            return "title"
        case .createdAt:
            return "createdAt"
        case .updatedAt:
            return "updatedAt"
        }
    }
    
    // MARK: - 批量操作
    
    func createDocuments(_ documents: [CDDocument]) async throws -> [CDDocument] {
        do {
            // 创建后台上下文以提高性能
            let backgroundContext = coreDataManager.newBackgroundContext()
            
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CDDocument], Error>) in
                backgroundContext.perform {
                    var createdDocuments: [CDDocument] = []
                    
                    do {
                        // 批量创建实体
                        for document in documents {
                            let entity = DocumentEntity(context: backgroundContext)
                            entity.documentModel = document
                            createdDocuments.append(entity.documentModel)
                        }
                        
                        // 保存上下文
                        try backgroundContext.save()
                        
                        // 更新缓存
                        self.documentCache.cacheDocuments(createdDocuments)
                        
                        // 通知文档变更
                        DispatchQueue.main.async {
                            for document in createdDocuments {
                                self.documentChangeSubject.send(.added(document))
                            }
                        }
                        
                        self.logger.info("批量创建了 \(documents.count) 个文档")
                        continuation.resume(returning: createdDocuments)
                    } catch {
                        self.logger.error("批量创建文档失败: \(error)")
                        continuation.resume(throwing: CoreDataError.saveFailed(error))
                    }
                }
            }
        } catch {
            logger.error("批量创建文档失败: \(error)")
            throw error
        }
    }
    
    func updateDocuments(_ documents: [CDDocument]) async throws -> [CDDocument] {
        do {
            // 创建后台上下文以提高性能
            let backgroundContext = coreDataManager.newBackgroundContext()
            
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CDDocument], Error>) in
                backgroundContext.perform {
                    var updatedDocuments: [CDDocument] = []
                    
                    do {
                        // 获取所有文档ID
                        let documentIds = documents.map { $0.id }
                        
                        // 批量获取实体
                        let fetchRequest = DocumentEntity.fetchRequest()
                        fetchRequest.predicate = NSPredicate(format: "id IN %@", documentIds)
                        
                        let existingEntities = try backgroundContext.fetch(fetchRequest)
                        let existingEntityMap = Dictionary(uniqueKeysWithValues: existingEntities.map { ($0.documentModel.id, $0) })
                        
                        // 批量更新实体
                        for document in documents {
                            if let entity = existingEntityMap[document.id] {
                                entity.documentModel = document
                                updatedDocuments.append(entity.documentModel)
                            } else {
                                self.logger.warning("未找到要更新的文档: \(document.id)")
                            }
                        }
                        
                        // 保存上下文
                        try backgroundContext.save()
                        
                        // 更新缓存
                        self.documentCache.cacheDocuments(updatedDocuments)
                        
                        // 通知文档变更
                        DispatchQueue.main.async {
                            for document in updatedDocuments {
                                self.documentChangeSubject.send(.updated(document))
                            }
                        }
                        
                        self.logger.info("批量更新了 \(updatedDocuments.count) 个文档")
                        continuation.resume(returning: updatedDocuments)
                    } catch {
                        self.logger.error("批量更新文档失败: \(error)")
                        continuation.resume(throwing: CoreDataError.saveFailed(error))
                    }
                }
            }
        } catch {
            logger.error("批量更新文档失败: \(error)")
            throw error
        }
    }
    
    func deleteDocuments(ids: [UUID]) async throws {
        do {
            // 创建后台上下文以提高性能
            let backgroundContext = coreDataManager.newBackgroundContext()
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                backgroundContext.perform {
                    do {
                        // 批量获取实体
                        let fetchRequest = DocumentEntity.fetchRequest()
                        fetchRequest.predicate = NSPredicate(format: "id IN %@", ids)
                        
                        let entities = try backgroundContext.fetch(fetchRequest)
                        
                        // 批量删除实体
                        for entity in entities {
                            backgroundContext.delete(entity)
                        }
                        
                        // 保存上下文
                        try backgroundContext.save()
                        
                        // 移除缓存
                        self.documentCache.invalidateDocuments(ids: ids)
                        
                        // 通知文档变更
                        DispatchQueue.main.async {
                            for id in ids {
                                self.documentChangeSubject.send(.deleted(id))
                            }
                        }
                        
                        self.logger.info("批量删除了 \(entities.count) 个文档")
                        continuation.resume()
                    } catch {
                        self.logger.error("批量删除文档失败: \(error)")
                        continuation.resume(throwing: CoreDataError.deleteFailed(error))
                    }
                }
            }
        } catch {
            logger.error("批量删除文档失败: \(error)")
            throw error
        }
    }
} 