import SwiftUI

struct HomeView: View {
    @State private var showSettings = false
    
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
                    .background(Color.blue)
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
        }
    }
} 