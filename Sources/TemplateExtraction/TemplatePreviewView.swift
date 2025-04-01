import SwiftUI

/// 模板预览视图，用于展示PPT模板的预览界面
public struct TemplatePreviewView: View {
    /// 被预览的模板信息
    private let templateInfo: PPTLayoutExtractor.PPTTemplateInfo
    /// 选中的布局索引
    @State private var selectedLayoutIndex: Int = 0
    /// 预览模式
    @State private var previewMode: PreviewMode = .layout
    /// 是否显示布局网格
    @State private var showLayoutGrid: Bool = false
    /// 预览比例
    @State private var zoomLevel: CGFloat = 1.0
    
    /// 预览模式枚举
    public enum PreviewMode: String, CaseIterable, Identifiable {
        case layout = "布局"
        case theme = "主题"
        case style = "样式"
        
        public var id: String { self.rawValue }
    }
    
    /// 初始化模板预览视图
    /// - Parameter templateInfo: 要预览的模板信息
    public init(templateInfo: PPTLayoutExtractor.PPTTemplateInfo) {
        self.templateInfo = templateInfo
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            previewToolbar
            
            // 主预览区域
            GeometryReader { geometry in
                ZStack {
                    // 背景
                    Color(.systemGray6)
                        .ignoresSafeArea()
                    
                    // 预览内容
                    VStack {
                        // 预览内容取决于当前选择的预览模式
                        switch previewMode {
                        case .layout:
                            layoutPreview
                        case .theme:
                            themePreview
                        case .style:
                            stylePreview
                        }
                    }
                    .frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.9)
                    .background(Color.white)
                    .cornerRadius(8)
                    .shadow(radius: 2)
                    .scaleEffect(zoomLevel)
                }
            }
            
            // 底部控制栏
            previewControlBar
        }
    }
    
    // MARK: - 组件
    
    /// 顶部工具栏
    private var previewToolbar: some View {
        HStack {
            // 模式选择器
            Picker("预览模式", selection: $previewMode) {
                ForEach(PreviewMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 250)
            
            Spacer()
            
            // 显示网格切换
            Toggle(isOn: $showLayoutGrid) {
                Label("显示网格", systemImage: "square.grid.2x2")
            }
            .toggleStyle(.button)
            .frame(width: 100)
            
            // 缩放控制
            HStack {
                Button(action: {
                    zoomLevel = max(zoomLevel - 0.1, 0.5)
                }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                
                Text("\(Int(zoomLevel * 100))%")
                    .frame(width: 50)
                
                Button(action: {
                    zoomLevel = min(zoomLevel + 0.1, 2.0)
                }) {
                    Image(systemName: "plus.magnifyingglass")
                }
            }
            .frame(width: 150)
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    /// 布局预览
    private var layoutPreview: some View {
        VStack {
            if !templateInfo.layouts.isEmpty {
                // 获取当前选中的布局
                let layout = templateInfo.layouts[safe: selectedLayoutIndex] ?? templateInfo.layouts.first!
                
                // 布局名称和类型
                Text("\(layout.name) (\(layout.type.localizedName))")
                    .font(.headline)
                    .padding(.bottom, 5)
                
                // 布局预览
                ZStack {
                    // 幻灯片背景
                    slideBackground(for: layout)
                    
                    // 如果显示网格，则绘制网格线
                    if showLayoutGrid {
                        layoutGrid
                    }
                    
                    // 显示占位符
                    ForEach(layout.placeholders, id: \.id) { placeholder in
                        placeholderView(for: placeholder)
                    }
                    
                    // 显示布局元素
                    ForEach(layout.elements, id: \.id) { element in
                        elementView(for: element)
                    }
                }
                .aspectRatio(templateInfo.slideSize.width / templateInfo.slideSize.height, contentMode: .fit)
                .overlay(
                    Rectangle()
                        .stroke(Color.gray, lineWidth: 1)
                )
            } else {
                Text("无可用布局")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    /// 主题预览
    private var themePreview: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 主题名称
            Text("主题: \(templateInfo.theme.name)")
                .font(.headline)
            
            // 颜色方案预览
            VStack(alignment: .leading, spacing: 10) {
                Text("颜色方案")
                    .font(.subheadline)
                
                HStack(spacing: 8) {
                    colorSwatch(templateInfo.theme.colorScheme.background1, name: "背景1")
                    colorSwatch(templateInfo.theme.colorScheme.text1, name: "文本1")
                    colorSwatch(templateInfo.theme.colorScheme.background2, name: "背景2")
                    colorSwatch(templateInfo.theme.colorScheme.text2, name: "文本2")
                }
                
                HStack(spacing: 8) {
                    colorSwatch(templateInfo.theme.colorScheme.accent1, name: "强调1")
                    colorSwatch(templateInfo.theme.colorScheme.accent2, name: "强调2")
                    colorSwatch(templateInfo.theme.colorScheme.accent3, name: "强调3")
                    colorSwatch(templateInfo.theme.colorScheme.accent4, name: "强调4")
                    colorSwatch(templateInfo.theme.colorScheme.accent5, name: "强调5")
                    colorSwatch(templateInfo.theme.colorScheme.accent6, name: "强调6")
                }
                
                HStack(spacing: 8) {
                    colorSwatch(templateInfo.theme.colorScheme.hyperlink, name: "超链接")
                    colorSwatch(templateInfo.theme.colorScheme.followedHyperlink, name: "已访问")
                }
            }
            
            // 字体方案预览
            VStack(alignment: .leading, spacing: 10) {
                Text("字体方案")
                    .font(.subheadline)
                
                Group {
                    Text("标题字体: \(templateInfo.theme.fontScheme.majorFont.latinFont)")
                    Text("正文字体: \(templateInfo.theme.fontScheme.minorFont.latinFont)")
                }
                .padding(.leading)
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    /// 样式预览
    private var stylePreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 标题
            Text("样式预览")
                .font(.headline)
                .padding(.bottom, 10)
            
            // 文本样式预览
            if !templateInfo.styles.textStyles.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("文本样式")
                        .font(.subheadline)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 15) {
                            ForEach(Array(templateInfo.styles.textStyles.keys.sorted()), id: \.self) { key in
                                if let style = templateInfo.styles.textStyles[key] {
                                    textStylePreview(style, name: key)
                                }
                            }
                        }
                        .padding()
                    }
                    .frame(height: 150)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            
            // 形状样式预览
            if !templateInfo.styles.shapeStyles.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("形状样式")
                        .font(.subheadline)
                    
                    ScrollView(.horizontal) {
                        HStack(spacing: 15) {
                            ForEach(Array(templateInfo.styles.shapeStyles.keys.sorted()), id: \.self) { key in
                                if let style = templateInfo.styles.shapeStyles[key] {
                                    shapeStylePreview(style, name: key)
                                }
                            }
                        }
                        .padding()
                    }
                    .frame(height: 100)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    /// 底部控制栏
    private var previewControlBar: some View {
        HStack {
            // 布局选择器（仅在布局预览模式下显示）
            if previewMode == .layout && !templateInfo.layouts.isEmpty {
                Picker("布局", selection: $selectedLayoutIndex) {
                    ForEach(0..<templateInfo.layouts.count, id: \.self) { index in
                        Text(templateInfo.layouts[index].name).tag(index)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 200)
            }
            
            Spacer()
            
            // 额外控制按钮可以放在这里
        }
        .padding()
        .background(Color(.systemGray6))
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
    
    /// 占位符视图
    private func placeholderView(for placeholder: PPTLayoutExtractor.Placeholder) -> some View {
        ZStack {
            Rectangle()
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .background(Color.blue.opacity(0.05))
            
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
    
    /// 元素视图
    private func elementView(for element: PPTLayoutExtractor.TemplateElement) -> some View {
        ZStack {
            // 根据元素类型显示不同的视图
            switch element.type {
            case .textBox:
                Rectangle()
                    .stroke(Color.gray, lineWidth: 1)
                    .background(Color.white)
                    .overlay(
                        Image(systemName: "text.justify")
                            .foregroundColor(.gray)
                    )
            case .shape:
                Rectangle()
                    .stroke(Color.gray, lineWidth: 1)
                    .background(Color.gray.opacity(0.1))
            case .picture:
                Rectangle()
                    .stroke(Color.gray, lineWidth: 1)
                    .background(Color.gray.opacity(0.05))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            case .table:
                Rectangle()
                    .stroke(Color.gray, lineWidth: 1)
                    .background(Color.gray.opacity(0.05))
                    .overlay(
                        Image(systemName: "tablecells")
                            .foregroundColor(.gray)
                    )
            case .chart:
                Rectangle()
                    .stroke(Color.gray, lineWidth: 1)
                    .background(Color.gray.opacity(0.05))
                    .overlay(
                        Image(systemName: "chart.bar")
                            .foregroundColor(.gray)
                    )
            case .smartArt:
                Rectangle()
                    .stroke(Color.gray, lineWidth: 1)
                    .background(Color.gray.opacity(0.05))
                    .overlay(
                        Image(systemName: "flowchart")
                            .foregroundColor(.gray)
                    )
            case .media:
                Rectangle()
                    .stroke(Color.gray, lineWidth: 1)
                    .background(Color.gray.opacity(0.05))
                    .overlay(
                        Image(systemName: "play.rectangle")
                            .foregroundColor(.gray)
                    )
            case .group(let elements):
                // 显示组合元素(简化处理，实际需要递归显示内部元素)
                Rectangle()
                    .stroke(Color.gray, lineWidth: 1, dash: [5, 5])
                    .background(Color.gray.opacity(0.02))
                    .overlay(
                        Text("组合: \(elements.count) 个元素")
                            .font(.caption)
                            .foregroundColor(.gray)
                    )
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
    }
    
    /// 幻灯片背景
    private func slideBackground(for layout: PPTLayoutExtractor.PPTLayout) -> some View {
        GeometryReader { geometry in
            // 根据背景类型显示不同的背景
            switch layout.background.type {
            case .solid(let color):
                color
            case .gradient(let gradientBackground):
                // 渐变背景
                LinearGradient(
                    gradient: Gradient(stops: gradientBackground.stops.map { 
                        Gradient.Stop(color: $0.color, location: CGFloat($0.position))
                    }),
                    startPoint: .top,
                    endPoint: .bottom
                )
            case .image(let url):
                // 图片背景
                Color.white // 图片加载失败时的默认背景
                    .overlay(
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        }
                    )
            case .pattern(let patternBackground):
                // 图案背景（简化处理）
                Color(patternBackground.background)
            case .none:
                // 无背景
                Color.white
            }
        }
    }
    
    /// 颜色样例视图
    private func colorSwatch(_ color: Color, name: String) -> some View {
        VStack {
            Rectangle()
                .fill(color)
                .frame(width: 40, height: 40)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray, lineWidth: 0.5)
                )
            
            Text(name)
                .font(.caption)
                .frame(width: 50)
                .lineLimit(1)
        }
    }
    
    /// 文本样式预览
    private func textStylePreview(_ style: PPTLayoutExtractor.TextStyle, name: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name).font(.caption).foregroundColor(.secondary)
            
            // 示例文本
            Text("示例文本 Sample Text")
                .foregroundColor(style.textColor)
                .font(.system(size: min(style.fontSize, 24)))
                .fontWeight(style.isBold ? .bold : .regular)
                .italic(style.isItalic)
                .underline(style.hasUnderline)
                .strikethrough(style.hasStrikethrough)
                .multilineTextAlignment(convertTextAlignment(style.paragraphStyle.alignment))
                .lineSpacing(style.paragraphStyle.lineSpacing)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    /// 形状样式预览
    private func shapeStylePreview(_ style: PPTLayoutExtractor.ShapeStyle, name: String) -> some View {
        VStack {
            // 形状预览
            ZStack {
                // 根据填充类型创建背景
                Group {
                    switch style.fill {
                    case .solid(let color):
                        color
                    case .gradient(let gradientFill):
                        LinearGradient(
                            gradient: Gradient(stops: gradientFill.stops.map { 
                                Gradient.Stop(color: $0.color, location: CGFloat($0.position))
                            }),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    case .pattern:
                        Color.gray.opacity(0.2) // 简化处理
                    case .picture:
                        Color.gray.opacity(0.1) // 简化处理
                    case .none:
                        Color.clear
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: style.cornerRadius)
                        .stroke(style.line.color, lineWidth: style.line.width)
                )
                
                // 如果有阴影，添加阴影效果
                if let shadow = style.shadow {
                    RoundedRectangle(cornerRadius: style.cornerRadius)
                        .fill(Color.clear)
                        .shadow(
                            color: shadow.color.opacity(Double(shadow.opacity)),
                            radius: shadow.radius,
                            x: shadow.offset.width,
                            y: shadow.offset.height
                        )
                }
            }
            .frame(width: 60, height: 60)
            
            Text(name)
                .font(.caption)
                .frame(width: 70)
                .lineLimit(1)
        }
    }
    
    /// 转换TextAlignment到SwiftUI的TextAlignment
    private func convertTextAlignment(_ alignment: TextAlignment) -> SwiftUI.TextAlignment {
        switch alignment {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        }
    }
}

/// 为安全索引访问数组扩展Array
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - 预览

struct TemplatePreviewView_Previews: PreviewProvider {
    static var previews: some View {
        // 创建示例模板信息用于预览
        let templateInfo = createSampleTemplateInfo()
        
        return TemplatePreviewView(templateInfo: templateInfo)
            .previewLayout(.sizeThatFits)
            .padding()
    }
    
    // 创建示例模板信息
    static func createSampleTemplateInfo() -> PPTLayoutExtractor.PPTTemplateInfo {
        var templateInfo = PPTLayoutExtractor.PPTTemplateInfo(name: "示例模板")
        
        // 创建示例主题
        var theme = PPTLayoutExtractor.PPTTheme(name: "示例主题")
        
        // 创建示例母版
        var masterSlide = PPTLayoutExtractor.PPTMasterSlide(name: "示例母版")
        
        // 创建示例布局
        var titleLayout = PPTLayoutExtractor.PPTLayout(name: "标题布局", type: .title)
        titleLayout.masterSlideId = masterSlide.id
        
        // 添加占位符
        let titlePlaceholder = PPTLayoutExtractor.Placeholder(type: .title)
        let subtitlePlaceholder = PPTLayoutExtractor.Placeholder(type: .subtitle)
        
        // 设置占位符位置
        var titleFrame = CGRect(x: 50, y: 180, width: 860, height: 100)
        var subtitleFrame = CGRect(x: 50, y: 300, width: 860, height: 80)
        
        titlePlaceholder.frame = titleFrame
        subtitlePlaceholder.frame = subtitleFrame
        
        titleLayout.placeholders = [titlePlaceholder, subtitlePlaceholder]
        
        // 创建内容布局
        var contentLayout = PPTLayoutExtractor.PPTLayout(name: "内容布局", type: .titleAndContent)
        contentLayout.masterSlideId = masterSlide.id
        
        // 添加占位符
        let contentTitlePlaceholder = PPTLayoutExtractor.Placeholder(type: .title)
        let contentPlaceholder = PPTLayoutExtractor.Placeholder(type: .content)
        
        // 设置占位符位置
        var contentTitleFrame = CGRect(x: 50, y: 30, width: 860, height: 60)
        var contentFrame = CGRect(x: 50, y: 100, width: 860, height: 380)
        
        contentTitlePlaceholder.frame = contentTitleFrame
        contentPlaceholder.frame = contentFrame
        
        contentLayout.placeholders = [contentTitlePlaceholder, contentPlaceholder]
        
        // 添加样式
        var titleStyle = PPTLayoutExtractor.TextStyle()
        titleStyle.fontFamily = "Arial"
        titleStyle.fontSize = 44
        titleStyle.fontWeight = .bold
        titleStyle.textColor = .black
        
        var bodyStyle = PPTLayoutExtractor.TextStyle()
        bodyStyle.fontFamily = "Arial"
        bodyStyle.fontSize = 24
        bodyStyle.textColor = Color(white: 0.2)
        
        var primaryShapeStyle = PPTLayoutExtractor.ShapeStyle()
        primaryShapeStyle.fill = .solid(Color(red: 0.2, green: 0.4, blue: 0.8, opacity: 0.1))
        primaryShapeStyle.line.color = Color(red: 0.2, green: 0.4, blue: 0.8)
        primaryShapeStyle.line.width = 2
        primaryShapeStyle.cornerRadius = 4
        
        // 添加到模板信息
        templateInfo.theme = theme
        templateInfo.masterSlides = [masterSlide]
        templateInfo.layouts = [titleLayout, contentLayout]
        templateInfo.styles.textStyles["title"] = titleStyle
        templateInfo.styles.textStyles["body"] = bodyStyle
        templateInfo.styles.shapeStyles["primary"] = primaryShapeStyle
        
        return templateInfo
    }
}
