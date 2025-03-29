// AdaptiveComponentsDemo.swift
// 测试应用，用于验证自适应组件

import SwiftUI

// MARK: - 组件展示视图
struct AdaptiveComponentsDemo: View {
    @State private var selectedTab = 0
    @State private var text = ""
    @State private var sliderValue = 0.5
    @State private var splitPosition: Double = 0.3
    @State private var isToggleOn = false
    
    // 用于分段控制器的选项
    private let tabOptions = ["按钮", "输入", "列表", "工具栏", "布局"]
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            AdaptiveToolbar(position: .top) {
                Text("自适应组件演示")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            
            // 选择器
            AdaptiveSegmentedPicker(
                selection: $selectedTab,
                options: Array(0..<tabOptions.count),
                labels: tabOptions
            )
            .padding(.vertical)
            
            // 主内容区域
            ScrollView {
                VStack(spacing: 20) {
                    switch selectedTab {
                    case 0:
                        buttonDemoView
                    case 1:
                        inputDemoView
                    case 2:
                        listDemoView
                    case 3:
                        toolbarDemoView
                    case 4:
                        layoutDemoView
                    default:
                        Text("未知选项")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            
            // 底部工具栏
            AdaptiveToolbar(position: .bottom) {
                HStack {
                    Spacer()
                    
                    Text("自适应组件状态：正常")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                    Spacer()
                    
                    AdaptiveButton("重置", icon: "arrow.clockwise", style: .secondary) {
                        resetDemoState()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 500)
        #endif
    }
    
    // 按钮演示
    private var buttonDemoView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("按钮组件").font(.title2)
            
            Divider()
            
            Group {
                Text("主要按钮").font(.headline)
                
                HStack(spacing: 12) {
                    AdaptiveButton("确定", style: .primary) {
                        print("点击了确定按钮")
                    }
                    
                    AdaptiveButton("提交", icon: "paperplane", style: .primary) {
                        print("点击了提交按钮")
                    }
                }
            }
            
            Group {
                Text("次要按钮").font(.headline)
                
                HStack(spacing: 12) {
                    AdaptiveButton("取消", style: .secondary) {
                        print("点击了取消按钮")
                    }
                    
                    AdaptiveButton("返回", icon: "arrow.left", style: .secondary) {
                        print("点击了返回按钮")
                    }
                }
            }
            
            Group {
                Text("警告按钮").font(.headline)
                
                HStack(spacing: 12) {
                    AdaptiveButton("删除", style: .destructive) {
                        print("点击了删除按钮")
                    }
                    
                    AdaptiveButton("清空", icon: "trash", style: .destructive) {
                        print("点击了清空按钮")
                    }
                }
            }
            
            Group {
                Text("链接按钮").font(.headline)
                
                HStack(spacing: 12) {
                    AdaptiveButton("查看更多", style: .plain) {
                        print("点击了查看更多")
                    }
                    
                    AdaptiveButton("帮助", icon: "questionmark.circle", style: .plain) {
                        print("点击了帮助")
                    }
                }
            }
        }
    }
    
    // 输入控件演示
    private var inputDemoView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("输入组件").font(.title2)
            
            Divider()
            
            AdaptiveTextField("标准输入", text: $text, placeholder: "请输入文本")
            
            AdaptiveTextField("电子邮件", text: $text, placeholder: "请输入电子邮件", keyboardType: .email)
            
            AdaptiveTextField("搜索", text: $text, placeholder: "搜索...", keyboardType: .search) {
                print("提交搜索: \(text)")
            }
            
            HStack {
                Text("滑块控件")
                Slider(value: $sliderValue)
                Text("\(Int(sliderValue * 100))%")
                    .frame(width: 40, alignment: .trailing)
            }
            
            Toggle("切换选项", isOn: $isToggleOn)
        }
    }
    
    // 列表项演示
    private var listDemoView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("列表组件").font(.title2)
            
            Divider()
            
            VStack(spacing: 0) {
                ForEach(0..<5) { index in
                    AdaptiveListItem {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.blue)
                            Text("文档 \(index + 1)")
                        }
                    } accessories: [
                        .info {
                            print("查看文档 \(index + 1) 信息")
                        },
                        .delete {
                            print("删除文档 \(index + 1)")
                        }
                    ] onTap: {
                        print("点击了文档 \(index + 1)")
                    }
                    
                    if index < 4 {
                        Divider()
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))
            )
            
            Divider()
            
            VStack(spacing: 0) {
                AdaptiveListItem {
                    Text("带披露指示器的项目")
                } accessories: [
                    .disclosure
                ] onTap: {
                    print("点击了带披露指示器的项目")
                }
                
                Divider()
                
                AdaptiveListItem {
                    Text("带自定义图标的项目")
                } accessories: [
                    .custom(icon: "star.fill") {
                        print("点击了星星")
                    }
                ] onTap: {
                    print("点击了带自定义图标的项目")
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
    
    // 工具栏演示
    private var toolbarDemoView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("工具栏组件").font(.title2)
            
            Divider()
            
            Text("顶部工具栏").font(.headline)
            
            AdaptiveToolbar(position: .top) {
                HStack {
                    AdaptiveButton("返回", icon: "arrow.left", style: .plain) {
                        print("工具栏返回")
                    }
                    
                    Spacer()
                    
                    Text("文档标题")
                        .font(.headline)
                    
                    Spacer()
                    
                    AdaptiveButton("保存", icon: "arrow.down.doc", style: .plain) {
                        print("工具栏保存")
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            
            Text("底部工具栏").font(.headline)
            
            AdaptiveToolbar(position: .bottom) {
                HStack {
                    AdaptiveButton("", icon: "pencil", style: .plain) {
                        print("编辑")
                    }
                    
                    Spacer()
                    
                    AdaptiveButton("", icon: "square.and.arrow.up", style: .plain) {
                        print("分享")
                    }
                    
                    Spacer()
                    
                    AdaptiveButton("", icon: "trash", style: .plain) {
                        print("删除")
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            
            #if os(macOS)
            Text("侧边工具栏").font(.headline)
            
            HStack {
                AdaptiveToolbar(position: .leading) {
                    VStack(spacing: 16) {
                        AdaptiveButton("", icon: "doc.text", style: .plain) {
                            print("文档")
                        }
                        
                        AdaptiveButton("", icon: "photo", style: .plain) {
                            print("图片")
                        }
                        
                        AdaptiveButton("", icon: "chart.bar", style: .plain) {
                            print("图表")
                        }
                        
                        Spacer()
                    }
                }
                .background(Color(.secondarySystemBackground))
                
                Text("这里是主内容区域")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            }
            .frame(height: 200)
            .border(Color.gray.opacity(0.2), width: 1)
            #endif
        }
    }
    
    // 布局演示
    private var layoutDemoView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("布局组件").font(.title2)
            
            Divider()
            
            Text("分割视图").font(.headline)
            
            AdaptiveSplitView(position: $splitPosition) {
                VStack {
                    Text("侧边栏内容")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("拖动分隔线调整大小")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .background(Color(.secondarySystemBackground))
            } trailing: {
                VStack {
                    Text("主要内容区域")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("分割位置: \(Int(splitPosition * 100))%")
                    
                    Spacer()
                    
                    AdaptiveButton("重置分割位置", style: .secondary) {
                        splitPosition = 0.3
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .background(Color(.systemBackground))
            }
            .frame(height: 300)
            .border(Color.gray.opacity(0.2), width: 1)
        }
    }
    
    // 重置演示状态
    private func resetDemoState() {
        selectedTab = 0
        text = ""
        sliderValue = 0.5
        splitPosition = 0.3
        isToggleOn = false
    }
}

#Preview {
    AdaptiveComponentsDemo()
} 