import SwiftUI

/// 保存的分析结果列表视图
public struct SavedResultsListView: View {
    @State private var savedResults: [DocumentAnalysisResult] = []
    @State private var selectedResult: DocumentAnalysisResult?
    @State private var showingDeleteConfirmation = false
    @State private var resultToDelete: UUID?
    @State private var searchText = ""
    
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        VStack {
            if savedResults.isEmpty {
                emptyStateView
            } else {
                resultsList
            }
        }
        .searchable(text: $searchText, prompt: "搜索已保存的分析结果")
        .navigationTitle("已保存的分析结果")
        .toolbar {
            if let selectedResult = selectedResult {
                Button("查看") {
                    openResult(selectedResult)
                }
            }
        }
        .onAppear {
            loadSavedResults()
        }
        .sheet(item: $selectedResult) { result in
            NavigationView {
                DocumentAnalysisResultView(result: result)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") {
                                selectedResult = nil
                            }
                        }
                    }
            }
        }
        .alert("删除确认", isPresented: $showingDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let id = resultToDelete {
                    deleteResult(withID: id)
                }
            }
        } message: {
            Text("确定要删除这个分析结果吗？此操作无法撤销。")
        }
    }
    
    // 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("没有保存的分析结果")
                .font(.title3)
            
            Text("分析文档后保存结果将显示在这里")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // 结果列表视图
    private var resultsList: some View {
        List {
            ForEach(filteredResults) { result in
                resultRow(for: result)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedResult = result
                    }
            }
            .onDelete { indexSet in
                let resultsToDelete = indexSet.map { filteredResults[$0] }
                if let firstResult = resultsToDelete.first {
                    resultToDelete = firstResult.id
                    showingDeleteConfirmation = true
                }
            }
        }
    }
    
    // 结果行视图
    private func resultRow(for result: DocumentAnalysisResult) -> some View {
        HStack {
            // 文档类型图标
            Image(systemName: result.sourceType.iconName)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 30, height: 30)
                .padding(.trailing, 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.headline)
                
                HStack {
                    Text(result.sourceType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray6))
                        .cornerRadius(4)
                    
                    Text("创建于 \(formattedDate(result.createdAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("\(result.sections.count) 个部分 • \(result.estimatedSlideCount) 张幻灯片")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    // 过滤的结果列表
    private var filteredResults: [DocumentAnalysisResult] {
        if searchText.isEmpty {
            return savedResults
        } else {
            return savedResults.filter { 
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.sections.contains { 
                    $0.title.localizedCaseInsensitiveContains(searchText) 
                }
            }
        }
    }
    
    // MARK: - 辅助方法
    
    // 加载保存的结果
    private func loadSavedResults() {
        savedResults = DocumentAnalysisStorage.shared.getAllResults()
            .sorted { $0.createdAt > $1.createdAt } // 按创建日期降序排序
    }
    
    // 打开结果
    private func openResult(_ result: DocumentAnalysisResult) {
        selectedResult = result
    }
    
    // 删除结果
    private func deleteResult(withID id: UUID) {
        if DocumentAnalysisStorage.shared.delete(withID: id) {
            loadSavedResults() // 重新加载列表
        }
    }
    
    // 格式化日期
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 预览
struct SavedResultsListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SavedResultsListView()
        }
    }
} 