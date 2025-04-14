import Foundation

public class TemplateService {
    public init() {}
    
    public func getDefaultTemplates() -> [Template] {
        return [
            Template(name: "空白模板"),
            Template(name: "商务模板"),
            Template(name: "教育模板")
        ]
    }
    
    public func createTemplate(name: String) -> Template {
        return Template(name: name)
    }
    
    public func applyTemplate(templateId: UUID, toDocument documentId: UUID) -> Bool {
        // 应用模板到文档的逻辑
        return true
    }
} 