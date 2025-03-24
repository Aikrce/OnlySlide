import Foundation
import os.log

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
    private let aiModelFactory: AIModelFactory
    private let contentProcessor: ContentProcessingPipeline
    private let logger = os.Logger(subsystem: "com.onlyslide", category: "usecase.document")
    
    // MARK: - Initialization
    public init(
        documentRepository: IDocumentRepository,
        aiModelFactory: AIModelFactory,
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
            let processedContent = try await model.processText(document.content ?? "")
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
            
            logger.error("Failed to process document: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func extractQuestions(from document: Document) async throws -> [Question] {
        guard let aiModel = aiModelFactory.getModel(named: "deepseek") else {
            throw ProcessingError.aiModelNotAvailable
        }
        
        let content = document.content ?? ""
        do {
            return try await aiModel.extractInsights(from: content) as? [Question] ?? []
        } catch {
            logger.error("Failed to extract questions: \(error.localizedDescription)")
            throw ProcessingError.processingFailed
        }
    }
    
    public func generatePresentation(from document: Document, questions: [Question]) async throws -> Presentation {
        guard let aiModel = aiModelFactory.getModel(named: "deepseek") else {
            throw ProcessingError.aiModelNotAvailable
        }
        
        do {
            let content = document.content ?? ""
            let questionTexts = questions.map { $0.text }.joined(separator: "\n")
            
            let prompt = """
            基于以下内容生成演示文稿:
            
            内容:
            \(content)
            
            问题:
            \(questionTexts)
            """
            
            let result = try await aiModel.generateText(prompt: prompt)
            
            // 这里需要解析生成的文本并创建演示文稿对象
            // 简化实现，创建一个基本的演示文稿对象
            return Presentation(
                id: UUID(),
                title: document.title ?? "生成的演示文稿",
                slides: [],
                createdAt: Date(),
                modifiedAt: Date()
            )
        } catch {
            logger.error("Failed to generate presentation: \(error.localizedDescription)")
            throw ProcessingError.processingFailed
        }
    }
}

// MARK: - Error Types
public enum ProcessingError: Error {
    case aiModelNotAvailable
    case processingFailed
    case invalidInput
    case modelNotFound
}