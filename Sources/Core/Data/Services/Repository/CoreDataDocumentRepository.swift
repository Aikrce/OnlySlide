import CoreData
import Foundation
import os.log
import Combine

protocol IDocumentPersistence {
    func fetchDocuments(for user: User) -> [Document]
    func fetchRecentDocuments(limit: Int) -> [Document]
    func fetchDocuments(withType type: String) -> [Document]
    func searchDocuments(keyword: String) -> [Document]
}

final class CoreDataDocumentRepository: CoreDataRepository<Document> {
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
        setupNotificationObservers()
        
        super.init(context: CoreDataStack.shared.viewContext)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
                if object.entity.name == "Document",
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
    
    private func handleChangedObjects(_ objects: Set<NSManagedObject>, changeType: (Document) -> DocumentChangeEvent) {
        for object in objects {
            guard object.entity.name == "Document" else { continue }
            
            // 在主上下文中获取对象
            let mainContext = coreDataManager.mainContext
            let objectID = object.objectID
            
            mainContext.perform {
                guard let mainObject = mainContext.object(with: objectID) as? NSManagedObject,
                      let document = self.convertToDocument(mainObject),
                      let documentId = mainObject.value(forKey: "id") as? UUID else { return }
                
                DispatchQueue.main.async {
                    self.documentChangeSubject.send(changeType(document))
                    
                    if let subject = self.documentObservers[documentId] {
                        subject.send(changeType(document))
                    }
                }
            }
        }
    }
    
    private func updateManagedObject(_ object: NSManagedObject, with document: Document) throws {
        // 设置基本属性
        object.setValue(document.id, forKey: "id")
        object.setValue(document.title, forKey: "title")
        object.setValue(document.content, forKey: "content")
        object.setValue(document.createdAt, forKey: "createdAt")
        object.setValue(document.updatedAt, forKey: "updatedAt")
        object.setValue(document.metadata, forKey: "metadata")
        object.setValue(document.status.rawValue, forKey: "status")
        object.setValue(document.sourceURL?.absoluteString, forKey: "sourceURL")
        object.setValue(document.type.rawValue, forKey: "type")
        
        // 处理复杂属性（如标签、用户、幻灯片等）可能需要额外的逻辑
        // 这里仅作示例，实际实现需要根据数据模型调整
    }
    
    private func convertToDocument(_ object: NSManagedObject) -> Document? {
        guard let id = object.value(forKey: "id") as? UUID,
              let title = object.value(forKey: "title") as? String,
              let content = object.value(forKey: "content") as? String,
              let createdAt = object.value(forKey: "createdAt") as? Date,
              let updatedAt = object.value(forKey: "updatedAt") as? Date,
              let statusRaw = object.value(forKey: "status") as? String,
              let typeRaw = object.value(forKey: "type") as? String,
              let status = DocumentStatus(rawValue: statusRaw),
              let type = DocumentType(rawValue: typeRaw) else {
            return nil
        }
        
        let metadata = object.value(forKey: "metadata") as? String
        
        var sourceURL: URL? = nil
        if let sourceURLString = object.value(forKey: "sourceURL") as? String {
            sourceURL = URL(string: sourceURLString)
        }
        
        // 获取标签、用户、幻灯片等关系也需要特殊处理
        // 这里仅作示例，实际实现需要根据数据模型调整
        
        return Document(
            id: id,
            title: title,
            content: content,
            createdAt: createdAt,
            updatedAt: updatedAt,
            metadata: metadata,
            status: status,
            sourceURL: sourceURL,
            type: type,
            tags: [],
            user: nil,
            slides: []
        )
    }
    
    private func convertDocumentToDictionary(_ document: Document) -> [String: Any] {
        var result: [String: Any] = [
            "id": document.id.uuidString,
            "title": document.title,
            "content": document.content,
            "createdAt": document.createdAt,
            "updatedAt": document.updatedAt,
            "status": document.status.rawValue,
            "type": document.type.rawValue
        ]
        
        if let metadata = document.metadata {
            result["metadata"] = metadata
        }
        
        if let sourceURL = document.sourceURL {
            result["sourceURL"] = sourceURL.absoluteString
        }
        
        // 处理标签、用户、幻灯片等复杂属性的字典转换
        // 这里仅作示例，实际实现需要根据数据模型调整
        
        return result
    }
}

// MARK: - IDocumentRepository Implementation
extension CoreDataDocumentRepository: IDocumentRepository {
    func getAllDocuments() async throws -> [Document] {
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
    
    func getDocument(id: UUID) async throws -> Document? {
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
    
    func createDocument(_ document: Document) async throws -> Document {
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
    
    func updateDocument(_ document: Document) async throws -> Document {
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
    
    func searchDocuments(query: DocumentSearchQuery) async throws -> [Document] {
        // 如果查询仅包含标签，尝试从缓存获取
        if let tags = query.text?.components(separatedBy: " ").filter({ $0.hasPrefix("#") }).map({ String($0.dropFirst()) }),
           !tags.isEmpty && query.types == nil && query.dateRange == nil {
            
            var cachedResults: [Document] = []
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
    
    func getDocumentsByTags(_ tags: [String]) async throws -> [Document] {
        // 尝试从缓存获取
        if !tags.isEmpty {
            var cachedResults: [Document] = []
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
    
    func syncDocuments() async throws -> [Document] {
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
    
    func resolveConflict(document: Document, resolution: ConflictResolution) async throws -> Document {
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
            
            return resolvedDocument as! Document
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
    
    func createDocuments(_ documents: [Document]) async throws -> [Document] {
        do {
            // 创建后台上下文以提高性能
            let backgroundContext = coreDataManager.newBackgroundContext()
            
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Document], Error>) in
                backgroundContext.perform {
                    var createdDocuments: [Document] = []
                    
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
    
    func updateDocuments(_ documents: [Document]) async throws -> [Document] {
        do {
            // 创建后台上下文以提高性能
            let backgroundContext = coreDataManager.newBackgroundContext()
            
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Document], Error>) in
                backgroundContext.perform {
                    var updatedDocuments: [Document] = []
                    
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