import SwiftUI

/// 模板编辑视图，用于编辑PPT模板的布局、样式和主题
public struct TemplateEditView: View {
    /// 被编辑的模板信息
    @State private var templateInfo: PPTLayoutExtractor.PPTTemplateInfo
    /// 选中的布局索引
    @State private var selectedLayoutIndex: Int = 0
    /// 编辑模式
    @State private var editMode: EditMode = .layout
    /// 选中的元素ID
    @State private var selectedElementId: String? = nil
    /// 是否显示布局网格
    @State private var showLayoutGrid: Bool = true
    /// 是否显示属性面板
    @State private var showPropertiesPanel: Bool = true
    /// 编辑是否有未保存的更改
    @State private var hasUnsavedChanges: Bool = false
    /// 是否显示保存确认对话框
    @State private var showingSaveConfirmation: Bool = false
    /// 保存完成回调
    var onSave: ((PPTLayoutExtractor.PPTTemplateInfo) -> Void)?
    
    /// 编辑模式枚举
    public enum EditMode: String, CaseIterable, Identifiable {
        case layout = "布局编辑"
        case theme = "主题编辑"
        case style = "样式编辑"
        
        public var id: String { self.rawValue }
    }
    
    /// 初始化模板编辑视图
    /// - Parameters:
    ///   - templateInfo: 要编辑的模板信息
    ///   - onSave: 保存完成的回调
    public init(templateInfo: PPTLayoutExtractor.PPTTemplateInfo, onSave: ((PPTLayoutExtractor.PPTTemplateInfo) -> Void)? = nil) {
        self._templateInfo = State(initialValue: templateInfo)
        self.onSave = onSave
    }
    
    public var body: some View {
        NavigationView {
            HSplitView {
                // 主编辑区域
                VStack(spacing: 0) {
                    // 工具栏
                    editToolbar
                    
                    // 编辑画布
                    GeometryReader { geometry in
                        ZStack {
                            // 背景
                            Color(.systemGray6)
                                .ignoresSafeArea()
                            
                            // 编辑内容
                            editContent
                                .frame(width: templateInfo.slideSize.width, height: templateInfo.slideSize.height)
                                .scaleEffect(calculateScale(for: geometry.size))
                        }
                    }
                }
                
                // 属性面板
                if showPropertiesPanel {
                    propertiesPanel
                        .frame(width: 280)
                        .background(Color(.systemGray6))
                }
            }
            .navigationTitle("编辑模板: \(templateInfo.name)")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("保存") {
                        showingSaveConfirmation = true
                    }
                    .disabled(!hasUnsavedChanges)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Toggle(isOn: $showPropertiesPanel) {
                        Image(systemName: "sidebar.right")
                    }
                    .toggleStyle(.button)
                }
            }
            .alert(isPresented: $showingSaveConfirmation) {
                Alert(
                    title: Text("保存更改"),
                    message: Text("确定要保存对模板的更改吗？"),
                    primaryButton: .default(Text("保存")) {
                        saveChanges()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    // MARK: - 组件
    
    /// 编辑工具栏
    private var editToolbar: some View {
        HStack {
            // 模式选择器
            Picker("编辑模式", selection: $editMode) {
                ForEach(EditMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 300)
            
            Spacer()
            
            // 显示网格切换
            Toggle(isOn: $showLayoutGrid) {
                Label("显示网格", systemImage: "square.grid.2x2")
            }
            .toggleStyle(.button)
            
            // 其他工具按钮
            // ...这里可以添加更多工具按钮
        }
        .padding()
        .background(Color(.systemGray5))
    }
    
    /// 编辑内容
    private var editContent: some View {
        ZStack {
            // 根据编辑模式显示不同内容
            switch editMode {
            case .layout:
                layoutEditView
            case .theme:
                themeEditView
            case .style:
                styleEditView
            }
        }
        .background(Color.white)
        .overlay(
            Rectangle()
                .stroke(Color.gray, lineWidth: 1)
        )
    }
    
    /// 布局编辑视图
    private var layoutEditView: some View {
        ZStack {
            // 这里是简化的布局编辑视图
            // 在实际实现中，应该有更详细的布局编辑功能
            
            // 显示网格
            if showLayoutGrid {
                layoutGrid
            }
            
            // 如果有布局
            if !templateInfo.layouts.isEmpty {
                // 获取当前选中的布局
                let layout = templateInfo.layouts[safe: selectedLayoutIndex] ?? templateInfo.layouts.first!
                
                // 显示占位符
                ForEach(layout.placeholders, id: \.id) { placeholder in
                    editablePlaceholderView(for: placeholder)
                }
                
                // 显示布局元素
                ForEach(layout.elements, id: \.id) { element in
                    editableElementView(for: element)
                }
            }
        }
    }
    
    /// 主题编辑视图
    private var themeEditView: some View {
        // 这里是简化的主题编辑视图
        Text("主题编辑功能")
            .font(.headline)
    }
    
    /// 样式编辑视图
    private var styleEditView: some View {
        // 这里是简化的样式编辑视图
        Text("样式编辑功能")
            .font(.headline)
    }
    
    /// 属性面板
    private var propertiesPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("属性")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray5))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 根据编辑模式和选中的元素显示不同的属性
                    switch editMode {
                    case .layout:
                        layoutPropertiesView
                    case .theme:
                        themePropertiesView
                    case .style:
                        stylePropertiesView
                    }
                }
                .padding()
            }
        }
    }
    
    /// 布局属性视图
    private var layoutPropertiesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 布局选择器
            if !templateInfo.layouts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("选择布局")
                        .font(.subheadline)
                    
                    Picker("布局", selection: $selectedLayoutIndex) {
                        ForEach(0..<templateInfo.layouts.count, id: \.self) { index in
                            Text(templateInfo.layouts[index].name).tag(index)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Divider()
                
                // 如果选中了某个元素，显示其属性
                if let selectedElementId = selectedElementId {
                    Text("元素属性")
                        .font(.subheadline)
                    
                    Text("ID: \(selectedElementId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // 这里应该显示元素的详细属性编辑控件
                    Text("元素属性编辑控件将在这里显示")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("未选中元素")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    /// 主题属性视图
    private var themePropertiesView: some View {
        Text("主题属性将在这里显示")
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
    
    /// 样式属性视图
    private var stylePropertiesView: some View {
        Text("样式属性将在这里显示")
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
    
    // MARK: - 辅助视图
    
    /// 布局网格
    private var layoutGrid: some View {
        GeometryReader { geometry in
            Path { path in
                // 横向网格线
                let horizontalSpacing = geometry.size.height / 10
                for i in 0...10 {
                    let y = horizontalSpacing * CGFloat(i)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
                
                // 纵向网格线
                let verticalSpacing = geometry.size.width / 10
                for i in 0...10 {
                    let x = verticalSpacing * CGFloat(i)
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
            }
            .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
        }
    }
    
    /// 可编辑的占位符视图
    private func editablePlaceholderView(for placeholder: PPTLayoutExtractor.Placeholder) -> some View {
        let isSelected = selectedElementId == placeholder.id
        
        return ZStack {
            Rectangle()
                .stroke(isSelected ? Color.blue : Color.blue.opacity(0.7), 
                        style: StrokeStyle(lineWidth: isSelected ? 2 : 1, dash: [5, 5]))
                .background(Color.blue.opacity(isSelected ? 0.1 : 0.05))
            
            VStack {
                Image(systemName: placeholderSystemImage(for: placeholder.type))
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                
                Text(placeholder.type.localizedName)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .frame(
            width: placeholder.frame.width,
            height: placeholder.frame.height
        )
        .position(
            x: placeholder.frame.midX,
            y: placeholder.frame.midY
        )
        .onTapGesture {
            selectedElementId = placeholder.id
        }
    }
    
    /// 可编辑的元素视图
    private func editableElementView(for element: PPTLayoutExtractor.TemplateElement) -> some View {
        let isSelected = selectedElementId == element.id
        
        return ZStack {
            // 元素背景
            Rectangle()
                .stroke(isSelected ? Color.orange : Color.gray, lineWidth: isSelected ? 2 : 1)
                .background(Color.gray.opacity(isSelected ? 0.1 : 0.05))
            
            // 根据元素类型显示不同的内容
            switch element.type {
            case .textBox:
                Image(systemName: "text.justify")
                    .foregroundColor(isSelected ? .orange : .gray)
            case .shape:
                EmptyView()
            case .picture:
                Image(systemName: "photo")
                    .foregroundColor(isSelected ? .orange : .gray)
            case .table:
                Image(systemName: "tablecells")
                    .foregroundColor(isSelected ? .orange : .gray)
            case .chart:
                Image(systemName: "chart.bar")
                    .foregroundColor(isSelected ? .orange : .gray)
            case .smartArt:
                Image(systemName: "flowchart")
                    .foregroundColor(isSelected ? .orange : .gray)
            case .media:
                Image(systemName: "play.rectangle")
                    .foregroundColor(isSelected ? .orange : .gray)
            case .group:
                Text("组")
                    .foregroundColor(isSelected ? .orange : .gray)
            }
        }
        .frame(
            width: element.frame.width,
            height: element.frame.height
        )
        .position(
            x: element.frame.midX,
            y: element.frame.midY
        )
        .onTapGesture {
            selectedElementId = element.id
        }
    }
    
    /// 根据占位符类型返回相应的系统图标名称
    private func placeholderSystemImage(for type: PPTLayoutExtractor.Placeholder.PlaceholderType) -> String {
        switch type {
        case .title:
            return "textformat.size.larger"
        case .subtitle:
            return "textformat.size.large"
        case .content:
            return "text.justify"
        case .picture:
            return "photo"
        case .chart:
            return "chart.bar"
        case .table:
            return "tablecells"
        case .smartArt:
            return "flowchart"
        case .media:
            return "play.rectangle"
        case .date:
            return "calendar"
        case .slideNumber:
            return "number"
        case .footer:
            return "text.alignleft"
        case .header:
            return "text.alignleft"
        case .custom:
            return "square.dashed"
        }
    }
    
    // MARK: - 辅助方法
    
    /// 计算缩放比例
    private func calculateScale(for size: CGSize) -> CGFloat {
        let widthScale = (size.width - 40) / templateInfo.slideSize.width
        let heightScale = (size.height - 40) / templateInfo.slideSize.height
        return min(widthScale, heightScale)
    }
    
    /// 保存更改
    private func saveChanges() {
        // 调用保存回调
        onSave?(templateInfo)
        
        // 重置未保存状态
        hasUnsavedChanges = false
    }
}

// MARK: - 预览

struct TemplateEditView_Previews: PreviewProvider {
    static var previews: some View {
        // 使用与TemplatePreviewView_Previews相同的示例数据
        let templateInfo = TemplatePreviewView_Previews.createSampleTemplateInfo()
        
        TemplateEditView(templateInfo: templateInfo)
    }
}
