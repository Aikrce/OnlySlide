#if os(macOS)
import SwiftUI
import AppKit

// MARK: - 文档状态组件
struct DocumentStatusView: View {
    @ObservedObject var documentManager: SlideDocumentManager
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(documentManager.isDocumentSaved ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
    
    private var statusText: String {
        if documentManager.isNewDocument {
            return "未保存"
        } else if documentManager.isDocumentSaved {
            return "已保存"
        } else {
            return "已修改"
        }
    }
}

// MARK: - macOS特有的滚动视图
struct MacOSScrollView<Content: View>: View {
    private let showsIndicators: Bool
    private let content: Content
    
    init(showsIndicators: Bool = true, @ViewBuilder content: () -> Content) {
        self.showsIndicators = showsIndicators
        self.content = content()
    }
    
    var body: some View {
        ScrollView {
            content
        }
        .background(Color(.windowBackgroundColor)) // 确保底色与macOS窗口保持一致
        .scrollContentBackground(.hidden) // 移除默认背景
    }
}

// MARK: - macOS特有的标签页组
struct MacOSTabGroup<Content: View>: View {
    private let content: Content
    private let selectedTabIndex: Binding<Int>
    private let labels: [String]
    
    init(selectedTabIndex: Binding<Int>, labels: [String], @ViewBuilder content: () -> Content) {
        self.selectedTabIndex = selectedTabIndex
        self.labels = labels
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标签标题栏
            HStack(spacing: 0) {
                ForEach(0..<labels.count, id: \.self) { index in
                    Button(action: {
                        selectedTabIndex.wrappedValue = index
                    }) {
                        Text(labels[index])
                            .font(.subheadline)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(selectedTabIndex.wrappedValue == index 
                                ? Color(.controlBackgroundColor)
                                : Color(.windowBackgroundColor))
                            .foregroundColor(selectedTabIndex.wrappedValue == index 
                                ? .primary 
                                : .secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if index < labels.count - 1 {
                        Divider()
                            .frame(height: 20)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .background(Color(.windowBackgroundColor))
            .overlay(
                Divider(),
                alignment: .bottom
            )
            
            // 内容区域
            content
        }
    }
}

// MARK: - macOS特有的工具栏按钮
struct ToolbarIconButton: View {
    let systemName: String
    let action: () -> Void
    let label: String
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(BorderlessButtonStyle())
        .help(label)
    }
}

// MARK: - 辅助组件：可折叠部分
struct CollapsibleSection<Content: View>: View {
    @State private var isExpanded: Bool = true
    let title: String
    let content: Content
    
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .frame(width: 16, height: 16)
                    
                    Text(title)
                        .font(.headline)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.controlBackgroundColor).opacity(0.1))
            }
            .buttonStyle(PlainButtonStyle())
            
            // 内容区域
            if isExpanded {
                content
                    .padding(12)
            }
        }
        .background(Color(.windowBackgroundColor))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - macOS特有的预览
#Preview {
    VStack(spacing: 20) {
        // 文档状态
        HStack {
            DocumentStatusView(documentManager: {
                let manager = SlideDocumentManager()
                manager.isDocumentSaved = false
                return manager
            }())
            
            DocumentStatusView(documentManager: {
                let manager = SlideDocumentManager()
                manager.isDocumentSaved = true
                return manager
            }())
        }
        .padding()
        .background(Color(.windowBackgroundColor))
        
        // 标签组
        MacOSTabGroup(selectedTabIndex: .constant(1), labels: ["Tab 1", "Tab 2", "Tab 3"]) {
            Text("Tab Content")
                .frame(height: 100)
                .frame(maxWidth: .infinity)
                .background(Color(.controlBackgroundColor))
        }
        .frame(width: 400)
        
        // 工具栏按钮
        HStack {
            ToolbarIconButton(systemName: "doc.badge.plus", action: {}, label: "New Document")
            ToolbarIconButton(systemName: "square.and.arrow.down", action: {}, label: "Save")
            ToolbarIconButton(systemName: "square.and.arrow.up", action: {}, label: "Export")
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        
        // 可折叠部分
        CollapsibleSection("折叠部分") {
            VStack(alignment: .leading) {
                Text("这是折叠部分的内容")
                Text("可以包含多行内容")
                Text("也可以包含其他组件")
            }
        }
        .frame(width: 300)
    }
    .padding()
    .background(Color(.windowBackgroundColor))
}
#endif 