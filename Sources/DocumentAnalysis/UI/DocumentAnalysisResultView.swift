import SwiftUI
import UniformTypeIdentifiers
import PDFKit

/// 显示文档分析结果的视图组件
public struct DocumentAnalysisResultView: View {
    let result: DocumentAnalysisResult
    @State private var selectedSectionIndex: Int? = 0
    @State private var isEditing = false
    @State private var showingSaveSuccess = false
    @State private var editableResult: DocumentAnalysisResult
    @State private var showingPDFExportSheet = false
    
    public init(result: DocumentAnalysisResult) {
        self.result = result
        self._editableResult = State(initialValue: result)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 文档信息头部
            documentHeader
                .padding()
                .background(Color(.systemBackground))
            
            Divider()
            
            // 主要内容区域
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // 左侧章节列表
                    sectionsList
                        .frame(width: min(geometry.size.width * 0.3, 250))
                        .background(Color(.systemGray6))
                    
                    Divider()
                    
                    // 右侧内容详情
                    if editableResult.sections.indices.contains(selectedSectionIndex ?? -1) {
                        ScrollView {
                            sectionDetailView(for: editableResult.sections[selectedSectionIndex!])
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        emptySelectionView
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { isEditing.toggle() }) {
                    Text(isEditing ? "完成" : "编辑")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: saveResult) {
                    Label("保存", systemImage: "square.and.arrow.down")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: exportAsPDF) {
                        Label("导出为PDF", systemImage: "doc.fill")
                    }
                    
                    Button(action: createSlides) {
                        Label("创建幻灯片", systemImage: "rectangle.stack.fill")
                    }
                } label: {
                    Label("更多", systemImage: "ellipsis.circle")
                }
            }
        }
        .alert("已保存", isPresented: $showingSaveSuccess) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("已成功保存分析结果")
        }
        .sheet(isPresented: $showingPDFExportSheet) {
            PDFExportView(documentResult: editableResult)
        }
    }
    
    // 文档头部信息
    private var documentHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(editableResult.title)
                .font(.title)
                .fontWeight(.bold)
            
            HStack {
                Label(editableResult.sourceType.displayName, 
                      systemImage: editableResult.sourceType.iconName)
                Spacer()
                Label("\(editableResult.sections.count) 个部分", systemImage: "list.bullet")
                Spacer()
                Label("约 \(editableResult.estimatedSlideCount) 张幻灯片", systemImage: "rectangle.stack")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            // 显示元数据
            if !editableResult.metadata.isEmpty {
                Divider()
                metadataView
            }
        }
    }
    
    // 元数据视图
    private var metadataView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("文档信息")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // 以网格形式显示元数据
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(Array(editableResult.metadata.keys.sorted()), id: \.self) { key in
                    if let value = editableResult.metadata[key], !value.isEmpty {
                        VStack(alignment: .leading) {
                            Text(key.capitalized)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(value)
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }
    
    // 左侧章节列表
    private var sectionsList: some View {
        List(editableResult.sections.indices, id: \.self, selection: $selectedSectionIndex) { index in
            let section = editableResult.sections[index]
            VStack(alignment: .leading) {
                Text(section.title.isEmpty ? "未命名部分" : section.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Text("\(section.contentItems.count) 项内容")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // 部分详情视图
    private func sectionDetailView(for section: DocumentSection) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(section.title.isEmpty ? "未命名部分" : section.title)
                .font(.title2)
                .fontWeight(.bold)
            
            ForEach(section.contentItems) { item in
                contentItemView(for: item)
            }
        }
    }
    
    // 内容项视图
    private func contentItemView(for item: ContentItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch item.type {
            case .paragraph:
                Text(item.text)
                    .fixedSize(horizontal: false, vertical: true)
            case .listItem:
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•")
                    Text(item.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 4)
            case .table:
                Text("[表格] \(item.text)")
                    .italic()
                    .foregroundColor(.secondary)
            case .image:
                Text("[图片] \(item.text)")
                    .italic()
                    .foregroundColor(.secondary)
            case .code:
                Text(item.text)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(4)
            case .quote:
                Text(item.text)
                    .italic()
                    .padding(.leading, 8)
                    .overlay(
                        Rectangle()
                            .frame(width: 2)
                            .foregroundColor(.gray),
                        alignment: .leading
                    )
            }
            
            if !item.children.isEmpty {
                ForEach(item.children) { child in
                    contentItemView(for: child)
                        .padding(.leading, 16)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // 无选择视图
    private var emptySelectionView: some View {
        VStack {
            Spacer()
            Text("请选择一个部分以查看详情")
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    // 保存结果
    private func saveResult() {
        let success = editableResult.save()
        showingSaveSuccess = success
    }
    
    // 导出为PDF功能
    private func exportAsPDF() {
        showingPDFExportSheet = true
    }
    
    // 创建幻灯片功能（未实现）
    private func createSlides() {
        // 在此实现创建幻灯片功能
        print("创建幻灯片功能尚未实现")
    }
}

// MARK: - 预览
struct DocumentAnalysisResultView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DocumentAnalysisResultView(
                result: DocumentAnalysisExample.createSampleResult()
            )
        }
    }
} 