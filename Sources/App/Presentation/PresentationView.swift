// PresentationView.swift
// 幻灯片演示模式视图

import SwiftUI

// MARK: - 演示模式视图
public struct PresentationView: AdaptiveView {
    @ObservedObject private var viewModel: SlideEditorViewModel
    @State private var currentIndex: Int
    @State private var isPlaying: Bool = true
    @State private var showControls: Bool = false
    @State private var timer: Timer?
    @Environment(\.presentationMode) private var presentationMode
    
    private let autoAdvanceInterval: TimeInterval?
    
    public init(
        viewModel: SlideEditorViewModel,
        startIndex: Int = 0,
        autoAdvanceInterval: TimeInterval? = nil
    ) {
        self.viewModel = viewModel
        self._currentIndex = State(initialValue: startIndex)
        self.autoAdvanceInterval = autoAdvanceInterval
    }
    
    // MARK: - macOS版本
    public func macView() -> some View {
        ZStack {
            // 背景
            Color.black.edgesIgnoringSafeArea(.all)
            
            // 当前幻灯片
            if !viewModel.slides.isEmpty && currentIndex < viewModel.slides.count {
                slideView(slide: viewModel.slides[currentIndex])
                    .transition(.opacity)
            }
            
            // 控制层
            VStack {
                Spacer()
                
                if showControls {
                    HStack {
                        Button(action: {
                            previousSlide()
                        }) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .disabled(currentIndex == 0)
                        
                        Spacer()
                        
                        Button(action: {
                            togglePlayPause()
                        }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .opacity(autoAdvanceInterval != nil ? 1 : 0)
                        
                        Spacer()
                        
                        Button(action: {
                            nextSlide()
                        }) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .disabled(currentIndex >= viewModel.slides.count - 1)
                    }
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding()
            
            // 进度指示器
            VStack {
                Spacer()
                
                HStack {
                    ForEach(0..<viewModel.slides.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, showControls ? 70 : 20)
            }
        }
        .onAppear {
            setupAutoAdvance()
        }
        .onDisappear {
            timer?.invalidate()
        }
        // 接收键盘事件
        .onTapGesture {
            withAnimation {
                showControls.toggle()
            }
        }
        .onKeyPress { key, modifiers in
            switch key.character {
            case " ":
                togglePlayPause()
                return .handled
            case "f":
                // 退出全屏
                presentationMode.wrappedValue.dismiss()
                return .handled
            case "esc":
                // 退出演示
                presentationMode.wrappedValue.dismiss()
                return .handled
            default:
                break
            }
            
            return .ignored
        }
        // 方向键事件
        .onKeyPress(.leftArrow) { _ in
            previousSlide()
            return .handled
        }
        .onKeyPress(.rightArrow) { _ in
            nextSlide()
            return .handled
        }
    }
    
    // MARK: - iOS版本
    public func iosView() -> some View {
        ZStack {
            // 背景
            Color.black.edgesIgnoringSafeArea(.all)
            
            // 当前幻灯片
            if !viewModel.slides.isEmpty && currentIndex < viewModel.slides.count {
                slideView(slide: viewModel.slides[currentIndex])
                    .transition(.opacity)
            }
            
            // 控制层
            VStack {
                // 顶部退出按钮
                if showControls {
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                    .padding()
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
                
                // 底部控制栏
                if showControls {
                    HStack {
                        Button(action: {
                            previousSlide()
                        }) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .disabled(currentIndex == 0)
                        
                        Spacer()
                        
                        Button(action: {
                            togglePlayPause()
                        }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .opacity(autoAdvanceInterval != nil ? 1 : 0)
                        
                        Spacer()
                        
                        Button(action: {
                            nextSlide()
                        }) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .disabled(currentIndex >= viewModel.slides.count - 1)
                    }
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding()
            
            // 进度指示器
            VStack {
                Spacer()
                
                HStack {
                    ForEach(0..<viewModel.slides.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, showControls ? 70 : 20)
            }
        }
        .onAppear {
            setupAutoAdvance()
        }
        .onDisappear {
            timer?.invalidate()
        }
        // 滑动手势
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.width > 0 {
                        // 向右滑动，上一页
                        previousSlide()
                    } else if value.translation.width < 0 {
                        // 向左滑动，下一页
                        nextSlide()
                    }
                }
        )
        // 点击手势
        .onTapGesture {
            withAnimation {
                showControls.toggle()
            }
        }
    }
    
    // MARK: - 共享方法
    
    // 幻灯片视图
    private func slideView(slide: SlideContent) -> some View {
        VStack(alignment: .leading) {
            Text(slide.title)
                .font(slide.style.titleFont)
                .foregroundColor(slide.style.titleColor)
                .padding(.bottom, 20)
            
            Text(slide.content)
                .font(slide.style.contentFont)
                .foregroundColor(slide.style.contentColor)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(slide.style.backgroundColor)
        .cornerRadius(slide.style.cornerRadius)
        .padding(40)
    }
    
    // 切换到下一张幻灯片
    private func nextSlide() {
        if currentIndex < viewModel.slides.count - 1 {
            withAnimation {
                currentIndex += 1
            }
        }
    }
    
    // 切换到上一张幻灯片
    private func previousSlide() {
        if currentIndex > 0 {
            withAnimation {
                currentIndex -= 1
            }
        }
    }
    
    // 切换播放/暂停状态
    private func togglePlayPause() {
        isPlaying.toggle()
        if isPlaying {
            setupAutoAdvance()
        } else {
            timer?.invalidate()
        }
    }
    
    // 设置自动前进计时器
    private func setupAutoAdvance() {
        guard let interval = autoAdvanceInterval, isPlaying else { return }
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            if currentIndex < viewModel.slides.count - 1 {
                withAnimation {
                    currentIndex += 1
                }
            } else {
                // 已到最后一张，停止计时器
                timer?.invalidate()
                isPlaying = false
            }
        }
    }
}

// MARK: - 演示启动器
public struct PresentationLauncher {
    public let viewModel: SlideEditorViewModel
    
    public init(viewModel: SlideEditorViewModel) {
        self.viewModel = viewModel
    }
    
    // 启动演示
    public func startPresentation() {
        #if os(macOS)
        launchMacOSPresentation()
        #else
        // iOS版本将在视图中实现
        #endif
    }
    
    #if os(macOS)
    // 在macOS上启动演示
    private func launchMacOSPresentation() {
        guard let screen = NSScreen.main else { return }
        
        // 创建窗口
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        
        // 创建演示视图
        let presentationView = PresentationView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: presentationView)
        
        // 配置窗口
        window.contentView = hostingView
        window.backgroundColor = .black
        window.level = .mainMenu + 1 // 置于最前
        
        // 进入全屏模式
        window.collectionBehavior = [.fullScreenPrimary]
        window.toggleFullScreen(nil)
        
        // 显示窗口
        window.makeKeyAndOrderFront(nil)
    }
    #endif
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
    
    return AdaptiveViewWrapper(content: PresentationView(viewModel: viewModel))
} 