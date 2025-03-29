// AdaptiveViewExample.swift
// 示例如何创建适应iOS和macOS的视图

import SwiftUI

struct SlideEditorView: AdaptiveView {
    let slideTitle: String
    @State private var zoomLevel: Double = 1.0
    
    // macOS版本
    func macView() -> some View {
        HStack(spacing: 0) {
            // macOS侧边栏（占据左侧25%空间）
            VStack {
                Text("幻灯片清单")
                    .font(.headline)
                    .padding()
                
                List(1...10, id: \.self) { index in
                    Text("幻灯片 \(index)")
                        .padding(.vertical, 8)
                }
                
                Spacer()
                
                // macOS特有的缩放控制
                HStack {
                    Text("缩放:")
                    Slider(value: $zoomLevel, in: 0.5...2.0)
                        .frame(width: 100)
                    Text("\(Int(zoomLevel * 100))%")
                }
                .padding()
            }
            .frame(width: 250)
            .background(Color(PlatformAdapter.color(red: 0.95, green: 0.95, blue: 0.97)))
            
            // 主编辑区（占据右侧空间）
            VStack {
                // 顶部工具栏
                HStack {
                    Text(slideTitle)
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("插入") {
                        // 插入操作
                    }
                    
                    Button("格式") {
                        // 格式操作
                    }
                    
                    Button("演示") {
                        // 演示操作
                    }
                }
                .padding()
                .background(Color(PlatformAdapter.color(red: 0.9, green: 0.9, blue: 0.92)))
                
                // 幻灯片编辑区
                ZStack {
                    Rectangle()
                        .fill(Color.white)
                        .border(Color.gray, width: 1)
                        .scaleEffect(zoomLevel)
                    
                    Text("幻灯片内容区域")
                        .font(.system(size: 20))
                        .scaleEffect(zoomLevel)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(PlatformAdapter.color(red: 0.85, green: 0.85, blue: 0.87)))
                .padding()
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    // iOS版本
    func iosView() -> some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                Text(slideTitle)
                    .font(.headline)
                
                Spacer()
                
                Button("编辑") {
                    // 编辑操作
                }
            }
            .padding()
            .background(Color(PlatformAdapter.color(red: 0.95, green: 0.95, blue: 0.97)))
            
            // 幻灯片编辑区
            ZStack {
                Rectangle()
                    .fill(Color.white)
                    .border(Color.gray, width: 1)
                    .scaleEffect(zoomLevel)
                
                Text("幻灯片内容区域")
                    .font(.system(size: 20))
                    .scaleEffect(zoomLevel)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(PlatformAdapter.color(red: 0.9, green: 0.9, blue: 0.92)))
            .padding()
            
            // 底部工具栏（iOS特有）
            HStack(spacing: 20) {
                Button(action: {
                    // 插入操作
                }) {
                    VStack {
                        Image(systemName: "plus.square")
                        Text("插入").font(.caption)
                    }
                }
                
                Button(action: {
                    // 格式操作
                }) {
                    VStack {
                        Image(systemName: "paintbrush")
                        Text("格式").font(.caption)
                    }
                }
                
                Button(action: {
                    // 演示操作
                }) {
                    VStack {
                        Image(systemName: "play.fill")
                        Text("演示").font(.caption)
                    }
                }
                
                Spacer()
                
                // iOS特有的缩放控制
                HStack {
                    Button("-") {
                        zoomLevel = max(0.5, zoomLevel - 0.1)
                    }
                    
                    Text("\(Int(zoomLevel * 100))%")
                        .frame(width: 50)
                    
                    Button("+") {
                        zoomLevel = min(2.0, zoomLevel + 0.1)
                    }
                }
            }
            .padding()
            .background(Color(PlatformAdapter.color(red: 0.95, green: 0.95, blue: 0.97)))
        }
    }
}

struct AdaptiveViewExample: View {
    var body: some View {
        AdaptiveViewWrapper(content: SlideEditorView(slideTitle: "演示文稿标题"))
    }
}

#Preview {
    AdaptiveViewExample()
} 