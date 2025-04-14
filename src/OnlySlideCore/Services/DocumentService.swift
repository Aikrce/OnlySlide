import Foundation

public class DocumentService {
    public init() {}
    
    public func createDocument(title: String) -> Document {
        return Document(title: title)
    }
    
    public func saveDocument(_ document: Document) -> Bool {
        // 这里应该实现实际的保存逻辑
        print("保存文档: \(document.title)")
        return true
    }
    
    public func loadDocument(id: UUID) -> Document? {
        // 这里应该实现实际的加载逻辑
        return nil
    }
} 