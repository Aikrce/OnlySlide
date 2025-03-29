#if os(macOS)
// MacOSPresenterView.swift
// macOS特有的演讲者视图，提供演讲辅助功能

import SwiftUI
import AppKit
import Combine

// MARK: - 演讲者视图
public struct MacOSPresenterView: View {
    @ObservedObject private var viewModel: SlideEditorViewModel
    @State private var currentIndex: Int
    @State private var elapsedTime: TimeInterval = 0
    @State private var isPlaying: Bool = true
    @State private var showControls: Bool = true
    @State private var timer: Timer?
    @State private var presentationStartTime = Date()
    @State private var slideStartTime = Date()
    @State private var slideElapsedTimes: [UUID: TimeInterval] = [:]
    @Environment(\.presentationMode) private var presentationMode
    
    private let slideDuration: TimeInterval
    
    public init(
        viewModel: SlideEditorViewModel,
        startIndex: Int = 0,
        slideDuration: TimeInterval = 60 // 默认每张幻灯片60秒
    ) {
        self.viewModel = viewModel
        self._currentIndex = State(initialValue: startIndex)
        self.slideDuration = slideDuration
    }
    
    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 顶部控制栏
                topControlBar
                    .frame(height: 50)
                    .background(Color.black)
                
                // 主内容区域
                HStack(spacing: 0) {
                    // 左侧 - 当前幻灯片、备注
                    VStack(spacing: 0) {
                        // 当前幻灯片
                        currentSlideView
                            .frame(height: geometry.size.height * 0.6)
                        
                        // 备注区域
                        notesView
                            .frame(height: geometry.size.height * 0.4 - 50)
                    }
                    .frame(width: geometry.size.width * 0.7)
                    
                    // 右侧 - 下一张幻灯片、计时器
                    VStack(spacing: 0) {
                        // 下一张幻灯片
                        nextSlideView
                            .frame(height: geometry.size.height * 0.4)
                        
                        // 幻灯片缩略图导航
                        slideThumbnailNavigator
                            .frame(height: geometry.size.height * 0.4)
                        
                        // 计时器区域
                        timerView
                            .frame(height: geometry.size.height * 0.2 - 50)
                    }
                    .frame(width: geometry.size.width * 0.3)
                    .background(Color.black.opacity(0.8))
                }
            }
            .background(Color.black)
            .onAppear {
                startPresentationTimer()
                restartSlideTimer()
            }
            .onDisappear {
                timer?.invalidate()
            }
            // 键盘事件
            .onKeyPress(.leftArrow) { _ in
                previousSlide()
                return .handled
            }
            .onKeyPress(.rightArrow) { _ in
                nextSlide()
                return .handled
            }
            .onKeyPress(.escape) { _ in
                endPresentation()
                return .handled
            }
            .onKeyPress("b") { _ in
                blankScreen()
                return .handled
            }
            .onKeyPress(" ") { _ in
                nextSlide()
                return .handled
            }
        }
    }
    
    // MARK: - 顶部控制栏
    private var topControlBar: some View {
        HStack {
            // 结束演示按钮
            Button(action: {
                endPresentation()
            }) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text("结束演示")
                }
                .foregroundColor(.white)
                .padding(8)
                .background(Color.red.opacity(0.7))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("结束演示并返回到编辑器")
            
            Spacer()
            
            // 当前幻灯片指示
            Text("\(currentIndex + 1) / \(viewModel.slides.count)")
                .foregroundColor(.white)
                .font(.headline)
            
            Spacer()
            
            // 黑屏按钮
            Button(action: {
                blankScreen()
            }) {
                HStack {
                    Image(systemName: "display")
                    Text("黑屏")
                }
                .foregroundColor(.white)
                .padding(8)
                .background(Color.gray.opacity(0.7))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("将观众屏幕变为黑屏")
            
            // 显示/隐藏控制
            Button(action: {
                withAnimation {
                    showControls.toggle()
                }
            }) {
                HStack {
                    Image(systemName: showControls ? "eye.slash" : "eye")
                    Text(showControls ? "隐藏控制" : "显示控制")
                }
                .foregroundColor(.white)
                .padding(8)
                .background(Color.blue.opacity(0.7))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help(showControls ? "隐藏控制面板" : "显示控制面板")
        }
        .padding(.horizontal)
    }
    
    // MARK: - 当前幻灯片视图
    private var currentSlideView: some View {
        VStack {
            Text("当前幻灯片")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.5))
            
            ZStack {
                // 幻灯片背景
                Color.gray.opacity(0.1)
                
                // 幻灯片内容
                if currentIndex < viewModel.slides.count {
                    let slide = viewModel.slides[currentIndex]
                    slideContentView(slide: slide)
                }
            }
            .padding(20)
        }
        .background(Color.black)
    }
    
    // MARK: - 下一张幻灯片视图
    private var nextSlideView: some View {
        VStack {
            Text("下一张幻灯片")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.5))
            
            ZStack {
                // 幻灯片背景
                Color.gray.opacity(0.1)
                
                // 幻灯片内容
                if currentIndex + 1 < viewModel.slides.count {
                    let slide = viewModel.slides[currentIndex + 1]
                    slideContentView(slide: slide, isPreview: true)
                } else {
                    Text("演示结束")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }
            .padding(10)
        }
        .background(Color.black)
    }
    
    // MARK: - 幻灯片内容视图
    private func slideContentView(slide: SlideContent, isPreview: Bool = false) -> some View {
        VStack(alignment: .leading) {
            Text(slide.title)
                .font(isPreview ? .title3 : slide.style.titleFont)
                .foregroundColor(slide.style.titleColor)
                .padding(.bottom, isPreview ? 10 : 20)
            
            Text(slide.content)
                .font(isPreview ? .body : slide.style.contentFont)
                .foregroundColor(slide.style.contentColor)
        }
        .padding(isPreview ? 20 : 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(slide.style.backgroundColor)
        .cornerRadius(slide.style.cornerRadius)
    }
    
    // MARK: - 备注视图
    private var notesView: some View {
        VStack {
            Text("演讲备注")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.5))
            
            ZStack {
                Color.gray.opacity(0.05)
                
                ScrollView {
                    Text(currentNotes)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(10)
        }
        .background(Color.black)
    }
    
    // 当前幻灯片的备注
    private var currentNotes: String {
        if currentIndex < viewModel.slides.count {
            let notes = viewModel.slides[currentIndex].notes
            if notes.isEmpty {
                return "此幻灯片没有备注。您可以在编辑器中添加备注以在演示时参考。"
            }
            return notes
        }
        return ""
    }
    
    // MARK: - 幻灯片缩略图导航
    private var slideThumbnailNavigator: some View {
        VStack {
            Text("幻灯片导航")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.5))
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80, maximum: 100))], spacing: 10) {
                    ForEach(Array(viewModel.slides.enumerated()), id: \.element.id) { index, slide in
                        slideThumbnail(slide: slide, index: index)
                            .onTapGesture {
                                jumpToSlide(index)
                            }
                    }
                }
                .padding(10)
            }
        }
        .background(Color.black)
    }
    
    // 幻灯片缩略图
    private func slideThumbnail(slide: SlideContent, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // 幻灯片内容预览
            ZStack {
                slide.style.backgroundColor
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(slide.title)
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(slide.style.titleColor)
                        .lineLimit(1)
                    
                    Text(slide.content)
                        .font(.system(size: 4))
                        .foregroundColor(slide.style.contentColor)
                        .lineLimit(2)
                }
                .padding(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(height: 50)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(index == currentIndex ? Color.blue : Color.clear, lineWidth: 2)
            )
            
            // 幻灯片标题
            Text("\(index + 1). \(slide.title)")
                .font(.system(size: 9))
                .foregroundColor(index == currentIndex ? .blue : .white)
                .lineLimit(1)
        }
    }
    
    // MARK: - 计时器视图
    private var timerView: some View {
        VStack {
            Text("计时器")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.5))
            
            VStack(spacing: 20) {
                // 总时间
                HStack {
                    Text("总时间:")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(formatTime(elapsedTime))
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                // 当前幻灯片时间
                HStack {
                    Text("当前幻灯片:")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(formatTime(currentSlideElapsedTime))
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(currentSlideElapsedTime > slideDuration ? .red : .white)
                }
                
                // 播放控制
                HStack(spacing: 20) {
                    Spacer()
                    
                    Button(action: {
                        previousSlide()
                    }) {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.system(size: 24))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                    .disabled(currentIndex <= 0)
                    
                    Button(action: {
                        togglePlayPause()
                    }) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 30))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                    
                    Button(action: {
                        nextSlide()
                    }) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 24))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                    .disabled(currentIndex >= viewModel.slides.count - 1)
                    
                    Spacer()
                }
            }
            .padding(15)
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
            .padding(10)
        }
        .background(Color.black)
    }
    
    // MARK: - 方法
    
    // 开始演示计时器
    private func startPresentationTimer() {
        presentationStartTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsedTime = Date().timeIntervalSince(presentationStartTime)
        }
    }
    
    // 重置当前幻灯片计时器
    private func restartSlideTimer() {
        slideStartTime = Date()
    }
    
    // 当前幻灯片已经过的时间
    private var currentSlideElapsedTime: TimeInterval {
        Date().timeIntervalSince(slideStartTime)
    }
    
    // 格式化时间
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // 切换到上一张幻灯片
    private func previousSlide() {
        guard currentIndex > 0 else { return }
        
        // 保存当前幻灯片花费的时间
        if currentIndex < viewModel.slides.count {
            let currentSlideId = viewModel.slides[currentIndex].id
            slideElapsedTimes[currentSlideId] = currentSlideElapsedTime
        }
        
        // 切换幻灯片
        currentIndex -= 1
        restartSlideTimer()
    }
    
    // 切换到下一张幻灯片
    private func nextSlide() {
        guard currentIndex < viewModel.slides.count - 1 else { return }
        
        // 保存当前幻灯片花费的时间
        if currentIndex < viewModel.slides.count {
            let currentSlideId = viewModel.slides[currentIndex].id
            slideElapsedTimes[currentSlideId] = currentSlideElapsedTime
        }
        
        // 切换幻灯片
        currentIndex += 1
        restartSlideTimer()
    }
    
    // 直接跳转到指定幻灯片
    private func jumpToSlide(_ index: Int) {
        guard index >= 0 && index < viewModel.slides.count else { return }
        
        // 保存当前幻灯片花费的时间
        if currentIndex < viewModel.slides.count {
            let currentSlideId = viewModel.slides[currentIndex].id
            slideElapsedTimes[currentSlideId] = currentSlideElapsedTime
        }
        
        // 跳转
        currentIndex = index
        restartSlideTimer()
    }
    
    // 切换播放/暂停状态
    private func togglePlayPause() {
        isPlaying.toggle()
        
        if isPlaying {
            // 重新计算开始时间，保持连续性
            let pausedTime = currentSlideElapsedTime
            slideStartTime = Date().addingTimeInterval(-pausedTime)
        }
    }
    
    // 结束演示
    private func endPresentation() {
        presentationMode.wrappedValue.dismiss()
    }
    
    // 黑屏功能
    private func blankScreen() {
        // 发送黑屏命令到观众视图
        // 这里需要实现与观众视图的通信
        NotificationCenter.default.post(name: NSNotification.Name("BlackScreen"), object: nil)
    }
}

// MARK: - 演讲者视图启动器
public class PresenterViewLauncher {
    private var viewModel: SlideEditorViewModel
    private var presenterWindow: NSWindow?
    private var audienceWindow: NSWindow?
    
    public init(viewModel: SlideEditorViewModel) {
        self.viewModel = viewModel
    }
    
    /// 启动演讲者模式 - 创建两个窗口：一个演讲者视图，一个观众视图
    public func launchPresenterMode() {
        // 避免创建多个窗口
        closeWindows()
        
        // 获取屏幕
        guard let mainScreen = NSScreen.main else { return }
        
        // 检测连接的外部屏幕
        let externalScreen = NSScreen.screens.first { $0 != mainScreen }
        
        // 创建演讲者视图
        let presenterView = MacOSPresenterView(viewModel: viewModel)
        
        // 创建演讲者窗口
        presenterWindow = NSWindow(
            contentRect: mainScreen.frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false,
            screen: mainScreen
        )
        
        if let window = presenterWindow {
            window.center()
            window.title = "OnlySlide 演讲者视图"
            window.contentView = NSHostingView(rootView: presenterView)
            window.makeKeyAndOrderFront(nil)
            window.delegate = WindowCloseDelegate { [weak self] in
                self?.audienceWindow?.close()
                self?.presenterWindow = nil
                self?.audienceWindow = nil
            }
            
            // 是否进入全屏
            window.collectionBehavior = [.fullScreenPrimary]
            // 不自动进入全屏，让用户决定
            // window.toggleFullScreen(nil)
        }
        
        // 创建观众视图
        if let externalScreen = externalScreen {
            // 如果有外部屏幕，在外部屏幕显示演示视图
            let presentationView = PresentationView(viewModel: viewModel)
            
            audienceWindow = NSWindow(
                contentRect: externalScreen.frame,
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false,
                screen: externalScreen
            )
            
            if let window = audienceWindow {
                window.contentView = NSHostingView(rootView: presentationView)
                window.title = "OnlySlide 演示"
                window.makeKeyAndOrderFront(nil)
                
                // 在外部屏幕自动进入全屏
                window.collectionBehavior = [.fullScreenPrimary]
                window.toggleFullScreen(nil)
            }
        } else {
            // 没有外部屏幕，提示用户
            let alert = NSAlert()
            alert.messageText = "未检测到外部显示器"
            alert.informativeText = "推荐使用外部显示器进行演示，以便观众查看幻灯片，演讲者查看备注。是否仍要继续？"
            alert.addButton(withTitle: "继续")
            alert.addButton(withTitle: "取消")
            
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                // 用户取消
                closeWindows()
            }
        }
    }
    
    /// 关闭所有窗口
    private func closeWindows() {
        presenterWindow?.close()
        audienceWindow?.close()
        presenterWindow = nil
        audienceWindow = nil
    }
}

// MARK: - 窗口关闭代理
class WindowCloseDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init()
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
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
    
    return MacOSPresenterView(viewModel: viewModel)
        .frame(width: 1200, height: 800)
}
#endif 