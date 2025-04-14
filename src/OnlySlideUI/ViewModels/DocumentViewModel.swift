import Foundation
import Combine
import OnlySlideCore

public class DocumentViewModel: ObservableObject {
    private let documentService = DocumentService()
    private let platformAdapter = createPlatformAdapter()
    
    @Published public var document: Document
    
    public init(document: Document? = nil) {
        self.document = document ?? Document(title: "新文档")
    }
    
    public func saveDocument() -> Bool {
        return documentService.saveDocument(document)
    }
    
    public func getScreenSize() -> CGSize {
        return platformAdapter.getScreenSize()
    }
} 