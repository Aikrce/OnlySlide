import Foundation
import Combine
import OnlySlideCore

public class AppStateManager: ObservableObject {
    @Published public var currentDocument: Document?
    @Published public var isDocumentOpen: Bool = false
    
    private let platformAdapter = createPlatformAdapter()
    private let documentService = DocumentService()
    
    public init() {}
    
    public func createNewDocument(title: String = "新文档") {
        currentDocument = documentService.createDocument(title: title)
        isDocumentOpen = true
    }
    
    public func openDocument() {
        if let url = platformAdapter.openDocument() {
            // 在实际应用中，这里应该加载文档
            print("打开文档: \(url.path)")
            isDocumentOpen = true
        }
    }
    
    public func saveCurrentDocument() -> Bool {
        guard let document = currentDocument else { return false }
        return documentService.saveDocument(document)
    }
}

