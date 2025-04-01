import SwiftUI
import DocumentAnalysis

struct AppHomeView: View {
    @State private var showSettings = false
    @State private var showDocumentAnalysis = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding()
                
                Text("OnlySlide")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("您的数据已准备就绪")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer().frame(height: 40)
                
                // 文档分析功能入口
                Button(action: {
                    showDocumentAnalysis = true
                }) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("文档分析")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                
                // 示例按钮
                Button(action: {
                    // 打开新文档
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("新建文档")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                
                Button(action: {
                    // 打开现有文档
                }) {
                    HStack {
                        Image(systemName: "folder.fill")
                        Text("打开文档")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // 版本信息
                Text("版本 1.0.0 (使用 Core Data 模型 V2)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarItems(
                trailing: Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "gear")
                }
            )
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showDocumentAnalysis) {
                NavigationView {
                    DocumentAnalysisView()
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
        }
    }
}

// MARK: - 预览
struct AppHomeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // iOS 预览
            AppHomeView()
                .previewDevice(PreviewDevice(rawValue: "iPhone 13"))
                .previewDisplayName("iOS - iPhone 13")
            
            // macOS 预览
            AppHomeView()
                .frame(width: 800, height: 600)
                .previewDevice(PreviewDevice(rawValue: "Mac"))
                .previewDisplayName("macOS")
            
            // iPad 预览
            AppHomeView()
                .previewDevice(PreviewDevice(rawValue: "iPad Pro (11-inch) (3rd generation)"))
                .previewDisplayName("iPadOS")
        }
    }
} 