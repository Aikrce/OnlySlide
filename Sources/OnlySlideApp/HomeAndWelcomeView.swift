import SwiftUI

/// 欢迎视图
struct WelcomeView: View {
    var importAction: () -> Void
    var browseTemplatesAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .padding()
            
            Text("欢迎使用 OnlySlide")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("从文档到精美演示文稿，只需简单几步")
                .font(.title3)
                .foregroundColor(.secondary)
                .padding(.bottom)
            
            VStack(spacing: 16) {
                Button(action: importAction) {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                            .font(.title2)
                        Text("导入文档")
                            .font(.title2)
                    }
                    .frame(minWidth: 200)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                Button(action: browseTemplatesAction) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title2)
                        Text("浏览模板")
                            .font(.title2)
                    }
                    .frame(minWidth: 200)
                    .padding()
                    .background(Color.secondary.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }
            }
            
            Spacer()
            
            // 快速入门指南
            HStack(spacing: 40) {
                featureCard(
                    icon: "doc.text.magnifyingglass",
                    title: "分析文档",
                    description: "导入PDF或Word文档，自动提取结构化内容"
                )
                
                featureCard(
                    icon: "rectangle.on.rectangle.angled",
                    title: "选择模板",
                    description: "从模板库中选择适合的模板，或导入自定义模板"
                )
                
                featureCard(
                    icon: "square.and.arrow.up",
                    title: "一键导出",
                    description: "将内容转换为精美演示文稿，支持多种格式"
                )
            }
            .padding(.bottom)
        }
        .padding()
    }
    
    /// 功能卡片
    func featureCard(icon: String, title: String, description: String) -> some View {
        VStack {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.blue)
                .padding(.bottom, 5)
            
            Text(title)
                .font(.headline)
                .padding(.bottom, 2)
            
            Text(description)
                .font(.caption)
                .multilineTextAlignment(.center)
                .frame(width: 200)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }
}

/// 分析进度视图
struct AnalysisProgressView: View {
    let progress: Float
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView("正在分析文档...", value: progress, total: 1.0)
                .progressViewStyle(.linear)
                .frame(width: 300)
            
            Text("\(Int(progress * 100))%")
                .font(.title2)
            
            Text("正在提取文档结构和内容，请稍候...")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

/// 主页视图
struct HomeView: View {
    var body: some View {
        VStack {
            Text("OnlySlide")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()
            
            Text("轻松将文档转换为精美演示文稿")
                .font(.title3)
                .foregroundColor(.secondary)
                .padding(.bottom, 40)
            
            Text("最近活动将显示在这里")
                .foregroundColor(.secondary)
                .padding()
        }
    }
} 