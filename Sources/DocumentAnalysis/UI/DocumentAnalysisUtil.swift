import Foundation

/// 用于示例和演示的文档分析辅助类
public enum DocumentAnalysisUtil {
    
    /// 创建一个配置好的文档分析引擎
    public static func createEngine() -> DocumentAnalysisEngine {
        let engine = DocumentAnalysisEngine()
        
        // 注册文本分析策略
        engine.register(strategy: TextAnalysisStrategy())
        
        // 注册Word文档分析策略
        engine.register(strategy: WordDocumentAnalysisStrategy())
        
        // 注册PDF文档分析策略
        engine.register(strategy: PDFDocumentAnalysisStrategy())
        
        return engine
    }
    
    /// 分析示例文本并返回结果
    public static func analyzeExampleText() async -> DocumentAnalysisResult? {
        let exampleText = """
        # OnlySlide 项目示例文档
        
        这是一个用于演示文档分析功能的示例文档。
        
        ## 文档分析功能
        
        OnlySlide 提供了强大的文档分析功能，可以从各种文档中提取结构化内容：
        
        - 识别文档标题和章节结构
        - 提取段落和列表内容
        - 分析文本格式和样式
        - 评估内容复杂度
        
        ### 技术实现
        
        文档分析引擎基于策略模式设计，支持多种文档格式：
        
        1. 纯文本文档
        2. Markdown文档
        3. Word文档（规划中）
        4. PDF文档（规划中）
        
        ## 后续计划
        
        在完成基础文档分析功能后，我们将继续开发以下功能：
        
        - 模板提取系统
        - 内容与模板融合
        - 跨平台适配
        - 导出功能
        """
        
        let engine = createEngine()
        
        do {
            let data = exampleText.data(using: .utf8)!
            return try await engine.analyze(content: data, filename: "example.txt")
        } catch {
            print("分析失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 创建样本分析结果（用于预览）
    public static func createSampleResult() -> DocumentAnalysisResult {
        // 创建示例结果
        var result = DocumentAnalysisResult(
            title: "示例文档",
            sections: [],
            metadata: ["author": "OnlySlide", "created": "2023-04-15"],
            sourceType: .text
        )
        
        // 添加第一个部分（标题部分）
        let section1 = DocumentSection(
            title: "OnlySlide 项目示例文档",
            level: 1,
            contentItems: [
                ContentItem(
                    type: .paragraph,
                    text: "这是一个用于演示文档分析功能的示例文档。"
                )
            ]
        )
        
        // 添加第二个部分（文档分析功能）
        let section2 = DocumentSection(
            title: "文档分析功能",
            level: 2,
            contentItems: [
                ContentItem(
                    type: .paragraph,
                    text: "OnlySlide 提供了强大的文档分析功能，可以从各种文档中提取结构化内容："
                ),
                ContentItem(type: .listItem, text: "识别文档标题和章节结构"),
                ContentItem(type: .listItem, text: "提取段落和列表内容"),
                ContentItem(type: .listItem, text: "分析文本格式和样式"),
                ContentItem(type: .listItem, text: "评估内容复杂度")
            ]
        )
        
        // 添加第三个部分（技术实现）
        let section3 = DocumentSection(
            title: "技术实现",
            level: 3,
            contentItems: [
                ContentItem(
                    type: .paragraph,
                    text: "文档分析引擎基于策略模式设计，支持多种文档格式："
                ),
                ContentItem(type: .listItem, text: "纯文本文档"),
                ContentItem(type: .listItem, text: "Markdown文档"),
                ContentItem(type: .listItem, text: "Word文档（规划中）"),
                ContentItem(type: .listItem, text: "PDF文档（规划中）")
            ]
        )
        
        // 添加第四个部分（后续计划）
        let section4 = DocumentSection(
            title: "后续计划",
            level: 2,
            contentItems: [
                ContentItem(
                    type: .paragraph,
                    text: "在完成基础文档分析功能后，我们将继续开发以下功能："
                ),
                ContentItem(type: .listItem, text: "模板提取系统"),
                ContentItem(type: .listItem, text: "内容与模板融合"),
                ContentItem(type: .listItem, text: "跨平台适配"),
                ContentItem(type: .listItem, text: "导出功能")
            ]
        )
        
        // 将所有部分添加到结果中
        result.sections = [section1, section2, section3, section4]
        
        return result
    }
}