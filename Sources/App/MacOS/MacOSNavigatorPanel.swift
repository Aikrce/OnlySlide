#if os(macOS)
// MacOSNavigatorPanel.swift
// macOS特有的导航器面板，显示幻灯片缩略图和大纲

import SwiftUI
import AppKit

// MARK: - 导航器面板
public struct MacOSNavigatorPanel: View {
    @ObservedObject private var viewModel: SlideEditorViewModel
    @State private var selectedTab = 0
    @State private var searchText = ""
    
    private enum TabType: Int, Identifiable {
        case thumbnails
        case outline
        case notes
        
        var id: Int { rawValue }
        
        var title: String {
            switch self {
            case .thumbnails: return "缩略图"
            case .outline: return "大纲"
            case .notes: return "备注"
            }
        }
        
        var icon: String {
            switch self {
            case .thumbnails: return "square.grid.2x2"
            case .outline: return "list.bullet"
            case .notes: return "note.text"
            }
        }
    }
    
    private let tabs: [TabType] = [.thumbnails, .outline, .notes]
    
    public init(viewModel: SlideEditorViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 标签选择器
            HStack {
                ForEach(tabs) { tab in
                    Button(action: {
                        selectedTab = tab.rawValue
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16))
                            
                            Text(tab.title)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab.rawValue ? Color.blue.opacity(0.2) : Color.clear)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            
            Divider()
            
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                
                TextField("搜索", text: $searchText)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(.textBackgroundColor).opacity(0.5))
            .cornerRadius(6)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            
            // 内容区域
            GeometryReader { geometry in
                Group {
                    switch selectedTab {
                    case TabType.thumbnails.rawValue:
                        thumbnailsTab
                    case TabType.outline.rawValue:
                        outlineTab
                    case TabType.notes.rawValue:
                        notesTab
                    default:
                        thumbnailsTab
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .frame(width: 250)
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - 缩略图标签
    private var thumbnailsTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(viewModel.slides.enumerated()), id: \.element.id) { index, slide in
                    slideThumbView(slide: slide, index: index)
                        .frame(height: 80)
                        .background(index == viewModel.currentSlideIndex ? Color.blue.opacity(0.2) : Color.clear)
                        .cornerRadius(6)
                        .onTapGesture {
                            viewModel.currentSlideIndex = index
                        }
                        .contextMenu {
                            Button("编辑") {
                                viewModel.currentSlideIndex = index
                            }
                            
                            Button("复制") {
                                let copySlide = slide
                                viewModel.slides.insert(copySlide, at: index + 1)
                                viewModel.currentSlideIndex = index + 1
                            }
                            
                            Divider()
                            
                            Button("删除") {
                                guard viewModel.slides.count > 1 else { return }
                                viewModel.slides.remove(at: index)
                                if viewModel.currentSlideIndex >= viewModel.slides.count {
                                    viewModel.currentSlideIndex = viewModel.slides.count - 1
                                }
                            }
                            .disabled(viewModel.slides.count <= 1)
                        }
                }
            }
            .padding(8)
        }
    }
    
    // MARK: - 大纲标签
    private var outlineTab: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(Array(viewModel.slides.enumerated()), id: \.element.id) { index, slide in
                    Button(action: {
                        viewModel.currentSlideIndex = index
                    }) {
                        HStack(alignment: .top) {
                            Text("\(index + 1).")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .frame(width: 20, alignment: .leading)
                            
                            Text(slide.title)
                                .font(.system(size: 12))
                                .foregroundColor(index == viewModel.currentSlideIndex ? .blue : .primary)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(6)
                        .background(index == viewModel.currentSlideIndex ? Color.blue.opacity(0.1) : Color.clear)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
    }
    
    // MARK: - 备注标签
    private var notesTab: some View {
        VStack {
            if viewModel.currentSlideIndex < viewModel.slides.count {
                let currentSlide = viewModel.slides[viewModel.currentSlideIndex]
                
                Text("幻灯片 \(viewModel.currentSlideIndex + 1) 备注")
                    .font(.headline)
                    .padding(.top)
                
                TextEditor(text: .constant("这里是关于"\(currentSlide.title)"幻灯片的演讲备注。\n\n添加您想要在演示时记住的要点。"))
                    .font(.system(size: 12))
                    .padding(6)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(6)
                    .padding(8)
            } else {
                Text("无选中幻灯片")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // 幻灯片缩略图
    private func slideThumbView(slide: SlideContent, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 幻灯片编号
            Text("幻灯片 \(index + 1)")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            
            // 幻灯片内容缩略图
            VStack(alignment: .leading, spacing: 4) {
                Text(slide.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(slide.style.titleColor)
                    .lineLimit(1)
                
                Text(slide.content)
                    .font(.system(size: 8))
                    .foregroundColor(slide.style.contentColor)
                    .lineLimit(2)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(slide.style.backgroundColor)
            .cornerRadius(4)
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(index == viewModel.currentSlideIndex ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - 预览
#Preview {
    let viewModel = SlideEditorViewModel(
        slides: [
            SlideContent(title: "欢迎使用OnlySlide", content: "创建专业演示文稿的最佳工具"),
            SlideContent(title: "简洁设计", content: "专注于内容，而不是复杂的界面", style: .modern),
            SlideContent(title: "跨平台", content: "在macOS和iOS上享受一致的体验", style: .light)
        ]
    )
    
    return MacOSNavigatorPanel(viewModel: viewModel)
        .frame(height: 600)
}
#endif 