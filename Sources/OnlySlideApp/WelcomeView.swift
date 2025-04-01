import SwiftUI

/// 欢迎页面视图，展示应用说明和主要功能入口
struct WelcomeView: View {
    /// 导入文档操作
    let importAction: () -> Void
    /// 浏览模板操作
    let browseTemplatesAction: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            // 标题和图标
            VStack(spacing: 16) {
                Image(systemName: "doc.text.image")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
                
                Text("欢迎使用 OnlySlide")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("简单高效的文档转换工具")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            // 功能介绍
            VStack(alignment: .leading, spacing: 20) {
                featureRow(
                    icon: "doc.text.magnifyingglass",
                    title: "智能文档分析",
                    description: "自动解析文档结构，识别标题、段落、列表和表格"
                )
                
                featureRow(
                    icon: "photo.on.rectangle.angled",
                    title: "专业模板库",
                    description: "精美设计的模板，一键应用到您的文档"
                )
                
                featureRow(
                    icon: "wand.and.stars",
                    title: "内容智能排版",
                    description: "根据内容特点自动分配到合适的幻灯片布局"
                )
                
                featureRow(
                    icon: "square.and.arrow.up",
                    title: "多种格式导出",
                    description: "导出为PowerPoint、PDF、图片或文本格式"
                )
            }
            .padding(.horizontal, 20)
            
            // 操作按钮
            HStack(spacing: 20) {
                Button(action: importAction) {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text("导入文档")
                    }
                    .frame(minWidth: 150)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                Button(action: browseTemplatesAction) {
                    HStack {
                        Image(systemName: "rectangle.grid.2x2")
                        Text("浏览模板")
                    }
                    .frame(minWidth: 150)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            
            // 底部提示
            Text("支持PDF和Word文档格式")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    /// 功能行视图
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 30)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
} 