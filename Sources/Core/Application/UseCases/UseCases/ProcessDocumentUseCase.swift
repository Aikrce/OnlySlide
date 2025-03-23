import Foundation
import Logging

/// 文档处理用例
public protocol IProcessDocumentUseCase {
    /// 处理文档
    /// - Parameter document: 待处理的文档
    /// - Returns: 处理后的文档
    func process(document: Document) async throws -> Document
    
    /// 提取问题
    /// - Parameter document: 源文档
    /// - Returns: 提取的问题列表
    func extractQuestions(from document: Document) async throws -> [Question]
    
    /// 生成PPT
    /// - Parameters:
    ///   - document: 源文档
    ///   - questions: 提取的问题
    /// - Returns: 生成的PPT文档
    func generatePresentation(from document: Document, questions: [Question]) async throws -> Presentation
}

/// 文档处理用例实现
public final class ProcessDocumentUseCaseImpl: IProcessDocumentUseCase {
    // MARK: - Properties
    private let documentRepository: IDocumentRepository
    private let aiModelFactory: DefaultAIModelFactory
    private let contentProcessor: ContentProcessingPipeline
    private let logger = Logger(label: "com.onlyslide.usecase.document")
    
    // MARK: - Initialization
    public init(
        documentRepository: IDocumentRepository,
        aiModelFactory: DefaultAIModelFactory = .shared,
        contentProcessor: ContentProcessingPipeline
    ) {
        self.documentRepository = documentRepository
        self.aiModelFactory = aiModelFactory
        self.contentProcessor = contentProcessor
    }
    
    // MARK: - Public Methods
    public func process(document: Document) async throws -> Document {
        logger.info("Starting document processing for document: \(document.id)")
        
        var updatedDocument = document
        updatedDocument.status = .processing
        
        do {
            // 1. 更新文档状态
            _ = try await documentRepository.update(updatedDocument)
            
            // 2. 获取AI模型
            guard let model = aiModelFactory.getModel(for: .textProcessing) else {
                throw ProcessingError.modelNotFound
            }
            
            // 3. 处理文档内容
            let processedContent = try await model.process(document.content)
            updatedDocument.content = processedContent
            
            // 4. 应用内容处理管道
            updatedDocument = try await contentProcessor.process(updatedDocument)
            
            // 5. 保存更新后的文档
            _ = try await documentRepository.update(updatedDocument)
            
            return updatedDocument
            
        } catch {
            // 处理失败，更新文档状态
            updatedDocument.metadata = "处理失败: \(error.localizedDescription)" // 使用字符串类型的metadata
            updatedDocument.status = .failed
            _ = try await documentRepository.update(updatedDocument)
            
            logger.error("Failed to process document: \(error)")
            throw error
        }
    }
    
    public func extractQuestions(from document: Document) async throws -> [Question] {
        guard let aiModel = aiModelFactory.getModel(named: "deepseek") else {
            throw ProcessingError.aiModelNotAvailable
        }
        
        return try await aiModel.extractQuestions(from: document.content ?? "")
    }
    
    public func generatePresentation(from document: Document, questions: [Question]) async throws -> Presentation {
        // 实现PPT生成逻辑
        // 这里需要集成具体的PPT生成功能
        fatalError("Not implemented")
    }
}

// MARK: - Error Types
public enum ProcessingError: Error {
    case aiModelNotAvailable
    case processingFailed
    case invalidInput
    case modelNotFound
} 