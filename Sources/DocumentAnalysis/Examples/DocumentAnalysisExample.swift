import Foundation
import SwiftUI

/// 文档分析示例
public class DocumentAnalysisExample {
    
    /// 创建并配置文档分析引擎
    public static func createEngine() -> DocumentAnalysisEngine {
        let engine = DocumentAnalysisEngine()
        
        // 注册文本分析策略
        engine.register(strategy: TextAnalysisStrategy())
        
        return engine
    }
    
    /// 处理示例文本
    public static func analyzeExampleText() async -> DocumentAnalysisResult? {
        let exampleText = """
        # 项目计划书
        
        ## 项目概述
        
        本项目旨在开发一款创新的演示文稿工具，帮助用户快速创建精美的幻灯片。
        
        ## 市场分析
        
        当前市场上的演示工具存在以下问题：
        - 学习曲线陡峭
        - 设计选项有限
        - 缺乏智能内容分析
        - 跨平台支持不足
        
        ## 技术方案
        
        ### 核心功能
        
        1. 文档分析引擎
        2. 模板提取系统
        3. 内容与模板融合
        
        ### 技术架构
        
        采用现代Swift架构，包括以下组件：
        - SwiftUI 用户界面
        - Core Data 数据存储
        - 文档处理框架
        
        ## 项目计划
        
        第一阶段：基础架构开发
        第二阶段：核心功能实现
        第三阶段：用户界面优化
        第四阶段：测试与发布
        
        ## 总结
        
        通过创新的技术方案，我们将打造一款革命性的演示工具。
        """
        
        let engine = createEngine()
        
        do {
            let data = exampleText.data(using: .utf8)!
            return try await engine.analyze(content: data, filename: "项目计划.txt")
        } catch {
            print("分析失败: \(error.localizedDescription)")
            return nil
        }
    }
}

/// 文档分析结果预览视图
public struct DocumentAnalysisResultView: View {
    let result: DocumentAnalysisResult
    
    public init(result: DocumentAnalysisResult) {
        self.result = result
    }
    
    public var body: some View {
        List {
            Section(header: Text("文档信息")) {
                LabeledContent("标题", value: result.title)
                LabeledContent("部分数量", value: "\(result.sections.count)")
                LabeledContent("内容项数量", value: "\(result.totalContentItemCount)")
                LabeledContent("估计幻灯片数", value: "\(result.estimatedSlideCount)")
                LabeledContent("源类型", value: result.sourceType.rawValue)
            }
            
            ForEach(result.sections) { section in
                Section(header: Text("\(section.level). \(section.title)")) {
                    ForEach(section.contentItems) { item in
                        VStack(alignment: .leading) {
                            HStack {
                                Text(item.type.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("复杂度: \(item.complexity.rawValue)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(item.text)
                                .padding(.top, 2)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("分析结果")
    }
}

/// 示例测试视图
public struct DocumentAnalysisExampleView: View {
    @State private var analysisResult: DocumentAnalysisResult?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            VStack {
                if isAnalyzing {
                    ProgressView("分析中...")
                        .padding()
                } else if let result = analysisResult {
                    DocumentAnalysisResultView(result: result)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("文档分析引擎示例")
                            .font(.title)
                        
                        Text("点击下面的按钮分析示例文本")
                            .foregroundColor(.secondary)
                        
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .padding()
                        }
                        
                        Button("分析示例文本") {
                            analyzeExample()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                    .padding()
                }
            }
            .navigationTitle("文档分析测试")
        }
    }
    
    private func analyzeExample() {
        isAnalyzing = true
        errorMessage = nil
        
        Task {
            do {
                if let result = await DocumentAnalysisExample.analyzeExampleText() {
                    await MainActor.run {
                        self.analysisResult = result
                        self.isAnalyzing = false
                    }
                } else {
                    throw NSError(domain: "DocumentAnalysis", code: 1, userInfo: [NSLocalizedDescriptionKey: "分析失败"])
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isAnalyzing = false
                }
            }
        }
    }
} 