#if os(macOS)
// MacOSMenuBuilder.swift
// macOS专用的菜单系统，集中管理所有菜单项和快捷键

import SwiftUI
import AppKit

// MARK: - 菜单管理器
public class MacOSMenuBuilder {
    // 单例实例
    public static let shared = MacOSMenuBuilder()
    
    // 主视图模型和管理器引用
    private weak var viewModel: SlideEditorViewModel?
    private weak var documentManager: SlideDocumentManager?
    private weak var appPreferences: AppPreferences?
    
    // 偏好设置窗口管理器
    private var preferencesWindowManager: PreferencesWindowManager?
    
    // 内容生成器窗口管理器
    private var contentGeneratorWindowManager: ContentGeneratorWindowManager?
    
    // 菜单委托
    private var menuDelegate: MenuDelegate?
    
    // 私有初始化方法，避免外部创建
    private init() {
        menuDelegate = MenuDelegate()
    }
    
    // 注册所需的模型和管理器
    public func registerDependencies(
        viewModel: SlideEditorViewModel,
        documentManager: SlideDocumentManager,
        appPreferences: AppPreferences
    ) {
        self.viewModel = viewModel
        self.documentManager = documentManager
        self.appPreferences = appPreferences
        self.preferencesWindowManager = PreferencesWindowManager(preferences: appPreferences)
        self.contentGeneratorWindowManager = ContentGeneratorWindowManager(viewModel: viewModel, documentManager: documentManager)
        
        // 更新菜单委托的引用
        menuDelegate?.viewModel = viewModel
        menuDelegate?.documentManager = documentManager
        menuDelegate?.contentGeneratorWindowManager = contentGeneratorWindowManager
        
        // 构建应用菜单
        buildApplicationMenu()
    }
    
    // 构建应用主菜单
    public func buildApplicationMenu() {
        guard let mainMenu = NSApp.mainMenu else { return }
        
        // 应用菜单已由系统创建，我们只需添加其他菜单
        
        // 构建文件菜单
        let fileMenu = createFileMenu()
        insertMenu(fileMenu, at: 1, in: mainMenu)
        
        // 构建编辑菜单
        let editMenu = createEditMenu()
        insertMenu(editMenu, at: 2, in: mainMenu)
        
        // 构建视图菜单
        let viewMenu = createViewMenu()
        insertMenu(viewMenu, at: 3, in: mainMenu)
        
        // 构建幻灯片菜单
        let slideMenu = createSlideMenu()
        insertMenu(slideMenu, at: 4, in: mainMenu)
        
        // 构建工具菜单
        let toolsMenu = createToolsMenu()
        insertMenu(toolsMenu, at: 5, in: mainMenu)
        
        // 构建演示菜单
        let presentationMenu = createPresentationMenu()
        insertMenu(presentationMenu, at: 6, in: mainMenu)
        
        // 构建窗口菜单
        let windowMenu = createWindowMenu()
        insertMenu(windowMenu, at: 7, in: mainMenu)
        
        // 构建帮助菜单
        let helpMenu = createHelpMenu()
        insertMenu(helpMenu, at: 8, in: mainMenu)
    }
    
    // MARK: - 辅助方法
    
    // 在主菜单中插入子菜单
    private func insertMenu(_ menu: NSMenu, at index: Int, in mainMenu: NSMenu) {
        // 检查该位置是否已有菜单
        if index < mainMenu.items.count {
            let existingItem = mainMenu.items[index]
            // 如果已有相同标题的菜单，替换它
            if existingItem.title == menu.title {
                mainMenu.removeItem(existingItem)
            }
        }
        
        // 创建菜单项
        let menuItem = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        menuItem.submenu = menu
        
        // 插入菜单
        if index < mainMenu.items.count {
            mainMenu.insertItem(menuItem, at: index)
        } else {
            mainMenu.addItem(menuItem)
        }
    }
    
    // MARK: - 菜单创建方法
    
    // 创建文件菜单
    private func createFileMenu() -> NSMenu {
        let menu = NSMenu(title: "文件")
        menu.delegate = menuDelegate
        
        // 新建
        let newItem = NSMenuItem(title: "新建", action: #selector(MenuDelegate.newDocument(_:)), keyEquivalent: "n")
        newItem.target = menuDelegate
        menu.addItem(newItem)
        
        // 打开
        let openItem = NSMenuItem(title: "打开...", action: #selector(MenuDelegate.openDocument(_:)), keyEquivalent: "o")
        openItem.target = menuDelegate
        menu.addItem(openItem)
        
        // 最近文件子菜单
        let recentDocsItem = NSMenuItem(title: "打开最近文件", action: nil, keyEquivalent: "")
        let recentDocsMenu = NSMenu(title: "打开最近文件")
        recentDocsMenu.delegate = menuDelegate // 动态更新最近文件列表
        recentDocsItem.submenu = recentDocsMenu
        menu.addItem(recentDocsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 关闭
        let closeItem = NSMenuItem(title: "关闭", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        menu.addItem(closeItem)
        
        // 保存
        let saveItem = NSMenuItem(title: "保存", action: #selector(MenuDelegate.saveDocument(_:)), keyEquivalent: "s")
        saveItem.target = menuDelegate
        menu.addItem(saveItem)
        
        // 另存为
        let saveAsItem = NSMenuItem(title: "另存为...", action: #selector(MenuDelegate.saveDocumentAs(_:)), keyEquivalent: "S")
        saveAsItem.target = menuDelegate
        menu.addItem(saveAsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 导出菜单
        let exportItem = NSMenuItem(title: "导出", action: nil, keyEquivalent: "")
        let exportMenu = NSMenu(title: "导出")
        
        // 导出为PDF
        let exportPDFItem = NSMenuItem(title: "导出为PDF...", action: #selector(MenuDelegate.exportToPDF(_:)), keyEquivalent: "e")
        exportPDFItem.target = menuDelegate
        exportMenu.addItem(exportPDFItem)
        
        // 导出为图像
        let exportImagesItem = NSMenuItem(title: "导出为图像...", action: #selector(MenuDelegate.exportToImages(_:)), keyEquivalent: "E")
        exportImagesItem.target = menuDelegate
        exportMenu.addItem(exportImagesItem)
        
        exportItem.submenu = exportMenu
        menu.addItem(exportItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 页面设置
        let pageSetupItem = NSMenuItem(title: "页面设置...", action: #selector(MenuDelegate.pageSetup(_:)), keyEquivalent: "P")
        pageSetupItem.target = menuDelegate
        menu.addItem(pageSetupItem)
        
        // 打印
        let printItem = NSMenuItem(title: "打印...", action: #selector(MenuDelegate.printDocument(_:)), keyEquivalent: "p")
        printItem.target = menuDelegate
        menu.addItem(printItem)
        
        return menu
    }
    
    // 创建编辑菜单
    private func createEditMenu() -> NSMenu {
        let menu = NSMenu(title: "编辑")
        
        // 撤销/重做
        menu.addItem(NSMenuItem(title: "撤销", action: Selector(("undo:")), keyEquivalent: "z"))
        menu.addItem(NSMenuItem(title: "重做", action: Selector(("redo:")), keyEquivalent: "Z"))
        menu.addItem(NSMenuItem.separator())
        
        // 剪切/复制/粘贴
        menu.addItem(NSMenuItem(title: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        menu.addItem(NSMenuItem(title: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        menu.addItem(NSMenuItem(title: "全选", action: #selector(NSStandardKeyBindingResponding.selectAll(_:)), keyEquivalent: "a"))
        menu.addItem(NSMenuItem.separator())
        
        // 查找
        let findItem = NSMenuItem(title: "查找", action: nil, keyEquivalent: "")
        let findMenu = NSMenu(title: "查找")
        
        findMenu.addItem(NSMenuItem(title: "查找...", action: #selector(NSResponder.performTextFinderAction(_:)), keyEquivalent: "f"))
        findMenu.items.last?.tag = NSTextFinder.Action.showFindInterface.rawValue
        
        findMenu.addItem(NSMenuItem(title: "查找下一个", action: #selector(NSResponder.performTextFinderAction(_:)), keyEquivalent: "g"))
        findMenu.items.last?.tag = NSTextFinder.Action.nextMatch.rawValue
        
        findMenu.addItem(NSMenuItem(title: "查找上一个", action: #selector(NSResponder.performTextFinderAction(_:)), keyEquivalent: "G"))
        findMenu.items.last?.tag = NSTextFinder.Action.previousMatch.rawValue
        
        findMenu.addItem(NSMenuItem(title: "查找和替换...", action: #selector(NSResponder.performTextFinderAction(_:)), keyEquivalent: "f"))
        findMenu.items.last?.tag = NSTextFinder.Action.showReplaceInterface.rawValue
        findMenu.items.last?.keyEquivalentModifierMask = [.command, .option]
        
        findItem.submenu = findMenu
        menu.addItem(findItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 特殊编辑项
        let formatItem = NSMenuItem(title: "格式", action: nil, keyEquivalent: "")
        let formatMenu = NSMenu(title: "格式")
        
        formatMenu.addItem(NSMenuItem(title: "字体", action: #selector(NSFontManager.orderFrontFontPanel(_:)), keyEquivalent: "t"))
        formatMenu.addItem(NSMenuItem(title: "颜色", action: #selector(MenuDelegate.showColorPanel(_:)), keyEquivalent: "C"))
        formatMenu.items.last?.target = menuDelegate
        
        formatItem.submenu = formatMenu
        menu.addItem(formatItem)
        
        return menu
    }
    
    // 创建视图菜单
    private func createViewMenu() -> NSMenu {
        let menu = NSMenu(title: "视图")
        
        // 缩放选项
        menu.addItem(NSMenuItem(title: "放大", action: #selector(MenuDelegate.zoomIn(_:)), keyEquivalent: "+"))
        menu.items.last?.target = menuDelegate
        
        menu.addItem(NSMenuItem(title: "缩小", action: #selector(MenuDelegate.zoomOut(_:)), keyEquivalent: "-"))
        menu.items.last?.target = menuDelegate
        
        menu.addItem(NSMenuItem(title: "实际大小", action: #selector(MenuDelegate.actualSize(_:)), keyEquivalent: "0"))
        menu.items.last?.target = menuDelegate
        
        menu.addItem(NSMenuItem.separator())
        
        // 显示/隐藏选项
        menu.addItem(NSMenuItem(title: "显示标尺", action: #selector(MenuDelegate.toggleRulers(_:)), keyEquivalent: "r"))
        menu.items.last?.target = menuDelegate
        
        menu.addItem(NSMenuItem(title: "显示网格", action: #selector(MenuDelegate.toggleGrid(_:)), keyEquivalent: "g"))
        menu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        menu.items.last?.target = menuDelegate
        
        menu.addItem(NSMenuItem.separator())
        
        // 面板选项
        menu.addItem(NSMenuItem(title: "显示导航器", action: #selector(MenuDelegate.toggleNavigator(_:)), keyEquivalent: "1"))
        menu.items.last?.keyEquivalentModifierMask = [.command, .option]
        menu.items.last?.target = menuDelegate
        
        menu.addItem(NSMenuItem(title: "显示检查器", action: #selector(MenuDelegate.toggleInspector(_:)), keyEquivalent: "2"))
        menu.items.last?.keyEquivalentModifierMask = [.command, .option]
        menu.items.last?.target = menuDelegate
        
        menu.addItem(NSMenuItem.separator())
        
        // 进入全屏
        menu.addItem(NSMenuItem(title: "进入全屏", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f"))
        menu.items.last?.keyEquivalentModifierMask = [.command, .control]
        
        return menu
    }
    
    // 创建幻灯片菜单
    private func createSlideMenu() -> NSMenu {
        let menu = NSMenu(title: "幻灯片")
        
        // 幻灯片操作
        menu.addItem(NSMenuItem(title: "添加幻灯片", action: #selector(MenuDelegate.addSlide(_:)), keyEquivalent: "n"))
        menu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        menu.items.last?.target = menuDelegate
        
        menu.addItem(NSMenuItem(title: "删除幻灯片", action: #selector(MenuDelegate.deleteSlide(_:)), keyEquivalent: ""))
        menu.items.last?.keyEquivalent = String(format: "%c", NSDeleteCharacter)
        menu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        menu.items.last?.target = menuDelegate
        
        menu.addItem(NSMenuItem(title: "复制幻灯片", action: #selector(MenuDelegate.duplicateSlide(_:)), keyEquivalent: "d"))
        menu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        menu.items.last?.target = menuDelegate
        
        menu.addItem(NSMenuItem.separator())
        
        // 导航
        menu.addItem(NSMenuItem(title: "下一张幻灯片", action: #selector(MenuDelegate.nextSlide(_:)), keyEquivalent: String(format: "%c", NSRightArrowFunctionKey)))
        menu.items.last?.target = menuDelegate
        
        menu.addItem(NSMenuItem(title: "上一张幻灯片", action: #selector(MenuDelegate.previousSlide(_:)), keyEquivalent: String(format: "%c", NSLeftArrowFunctionKey)))
        menu.items.last?.target = menuDelegate
        
        menu.addItem(NSMenuItem.separator())
        
        // 样式
        let styleItem = NSMenuItem(title: "样式", action: nil, keyEquivalent: "")
        let styleMenu = NSMenu(title: "样式")
        
        styleMenu.addItem(NSMenuItem(title: "标准", action: #selector(MenuDelegate.applyStandardStyle(_:)), keyEquivalent: "1"))
        styleMenu.items.last?.keyEquivalentModifierMask = [.command, .control]
        styleMenu.items.last?.target = menuDelegate
        
        styleMenu.addItem(NSMenuItem(title: "现代", action: #selector(MenuDelegate.applyModernStyle(_:)), keyEquivalent: "2"))
        styleMenu.items.last?.keyEquivalentModifierMask = [.command, .control]
        styleMenu.items.last?.target = menuDelegate
        
        styleMenu.addItem(NSMenuItem(title: "轻盈", action: #selector(MenuDelegate.applyLightStyle(_:)), keyEquivalent: "3"))
        styleMenu.items.last?.keyEquivalentModifierMask = [.command, .control]
        styleMenu.items.last?.target = menuDelegate
        
        styleItem.submenu = styleMenu
        menu.addItem(styleItem)
        
        return menu
    }
    
    // 创建工具菜单
    private func createToolsMenu() -> NSMenu {
        let menu = NSMenu(title: "工具")
        
        // 内容生成器
        menu.addItem(NSMenuItem(title: "内容生成器...", action: #selector(MenuDelegate.showContentGenerator(_:)), keyEquivalent: "g"))
        menu.items.last?.keyEquivalentModifierMask = [.command, .option]
        menu.items.last?.target = menuDelegate
        
        menu.addItem(NSMenuItem.separator())
        
        // 拼写和语法
        let spellingItem = NSMenuItem(title: "拼写和语法", action: nil, keyEquivalent: "")
        let spellingMenu = NSMenu(title: "拼写和语法")
        
        spellingMenu.addItem(NSMenuItem(title: "显示拼写和语法", action: #selector(NSText.showGuessPanel(_:)), keyEquivalent: ":"))
        spellingMenu.addItem(NSMenuItem(title: "检查文档", action: #selector(NSText.checkSpelling(_:)), keyEquivalent: ";"))
        
        spellingItem.submenu = spellingMenu
        menu.addItem(spellingItem)
        
        return menu
    }
    
    // 创建演示菜单
    private func createPresentationMenu() -> NSMenu {
        let menu = NSMenu(title: "演示")
        
        // 开始演示
        menu.addItem(NSMenuItem(title: "开始演示", action: #selector(MenuDelegate.startPresentation(_:)), keyEquivalent: "p"))
        menu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        menu.items.last?.target = menuDelegate
        
        // 演讲者视图
        menu.addItem(NSMenuItem(title: "演讲者视图", action: #selector(MenuDelegate.startPresenterView(_:)), keyEquivalent: "P"))
        menu.items.last?.keyEquivalentModifierMask = [.command, .shift, .option]
        menu.items.last?.target = menuDelegate
        
        menu.addItem(NSMenuItem.separator())
        
        // 演示设置
        let settingsItem = NSMenuItem(title: "演示设置", action: nil, keyEquivalent: "")
        let settingsMenu = NSMenu(title: "演示设置")
        
        // 自动播放设置
        settingsMenu.addItem(NSMenuItem(title: "自动播放", action: #selector(MenuDelegate.toggleAutoPlay(_:)), keyEquivalent: ""))
        settingsMenu.items.last?.target = menuDelegate
        
        // 过渡效果
        let transitionItem = NSMenuItem(title: "过渡效果", action: nil, keyEquivalent: "")
        let transitionMenu = NSMenu(title: "过渡效果")
        
        transitionMenu.addItem(NSMenuItem(title: "无", action: #selector(MenuDelegate.setTransition(_:)), keyEquivalent: ""))
        transitionMenu.items.last?.target = menuDelegate
        transitionMenu.items.last?.tag = 0
        
        transitionMenu.addItem(NSMenuItem(title: "淡入淡出", action: #selector(MenuDelegate.setTransition(_:)), keyEquivalent: ""))
        transitionMenu.items.last?.target = menuDelegate
        transitionMenu.items.last?.tag = 1
        
        transitionMenu.addItem(NSMenuItem(title: "滑动", action: #selector(MenuDelegate.setTransition(_:)), keyEquivalent: ""))
        transitionMenu.items.last?.target = menuDelegate
        transitionMenu.items.last?.tag = 2
        
        transitionItem.submenu = transitionMenu
        settingsMenu.addItem(transitionItem)
        
        settingsItem.submenu = settingsMenu
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 录制演示
        menu.addItem(NSMenuItem(title: "录制演示...", action: #selector(MenuDelegate.recordPresentation(_:)), keyEquivalent: "r"))
        menu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        menu.items.last?.target = menuDelegate
        
        return menu
    }
    
    // 创建窗口菜单
    private func createWindowMenu() -> NSMenu {
        let menu = NSMenu(title: "窗口")
        
        // 标准窗口菜单项
        menu.addItem(NSMenuItem(title: "最小化", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        menu.addItem(NSMenuItem(title: "缩放", action: #selector(NSWindow.zoom(_:)), keyEquivalent: ""))
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "前置全部窗口", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: ""))
        
        return menu
    }
    
    // 创建帮助菜单
    private func createHelpMenu() -> NSMenu {
        let menu = NSMenu(title: "帮助")
        
        // 帮助和支持
        menu.addItem(NSMenuItem(title: "OnlySlide 帮助", action: #selector(MenuDelegate.openHelp(_:)), keyEquivalent: "?"))
        menu.items.last?.target = menuDelegate
        
        menu.addItem(NSMenuItem.separator())
        
        // 检查更新
        menu.addItem(NSMenuItem(title: "检查更新...", action: #selector(MenuDelegate.checkForUpdates(_:)), keyEquivalent: ""))
        menu.items.last?.target = menuDelegate
        
        menu.addItem(NSMenuItem.separator())
        
        // 快捷键
        menu.addItem(NSMenuItem(title: "键盘快捷键", action: #selector(MenuDelegate.showKeyboardShortcuts(_:)), keyEquivalent: ""))
        menu.items.last?.target = menuDelegate
        
        // 偏好设置
        menu.addItem(NSMenuItem(title: "首选项...", action: #selector(MenuDelegate.showPreferences(_:)), keyEquivalent: ","))
        menu.items.last?.target = menuDelegate
        
        return menu
    }
    
    // MARK: - 公共方法
    
    // 显示偏好设置窗口
    public func showPreferences() {
        preferencesWindowManager?.showPreferences()
    }
    
    // 显示内容生成器窗口
    public func showContentGenerator() {
        contentGeneratorWindowManager?.showContentGenerator()
    }
}

// MARK: - 菜单委托
class MenuDelegate: NSObject, NSMenuDelegate {
    weak var viewModel: SlideEditorViewModel?
    weak var documentManager: SlideDocumentManager?
    weak var contentGeneratorWindowManager: ContentGeneratorWindowManager?
    
    // MARK: - 菜单动态更新
    
    // 动态更新菜单
    func menuNeedsUpdate(_ menu: NSMenu) {
        // 更新最近文件菜单
        if menu.title == "打开最近文件" {
            updateRecentFilesMenu(menu)
        }
    }
    
    // 更新最近文件菜单
    private func updateRecentFilesMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        
        guard let docManager = documentManager, !docManager.recentDocuments.isEmpty else {
            menu.addItem(NSMenuItem(title: "无最近文件", action: nil, keyEquivalent: ""))
            menu.items.last?.isEnabled = false
            return
        }
        
        // 添加最近文件
        for (index, url) in docManager.recentDocuments.enumerated() {
            let menuItem = NSMenuItem(title: url.lastPathComponent, action: #selector(openRecentFile(_:)), keyEquivalent: "")
            menuItem.representedObject = url
            menuItem.target = self
            menu.addItem(menuItem)
            
            // 最多显示10个最近文件
            if index >= 9 {
                break
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "清除菜单", action: #selector(clearRecentFiles(_:)), keyEquivalent: ""))
        menu.items.last?.target = self
    }
    
    // MARK: - 文件菜单动作
    
    @objc func newDocument(_ sender: Any) {
        documentManager?.newDocument()
    }
    
    @objc func openDocument(_ sender: Any) {
        Task {
            _ = await documentManager?.openDocument()
        }
    }
    
    @objc func openRecentFile(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        
        Task {
            _ = await documentManager?.loadDocument(from: url)
        }
    }
    
    @objc func clearRecentFiles(_ sender: Any) {
        documentManager?.recentDocuments.removeAll()
        UserDefaults.standard.removeObject(forKey: "recentDocuments")
    }
    
    @objc func saveDocument(_ sender: Any) {
        Task {
            // 从视图模型更新文档
            documentManager?.updateFromViewModel(viewModel!)
            
            // 保存文档
            _ = await documentManager?.saveDocument()
        }
    }
    
    @objc func saveDocumentAs(_ sender: Any) {
        Task {
            // 从视图模型更新文档
            documentManager?.updateFromViewModel(viewModel!)
            
            // 另存为
            _ = await documentManager?.saveDocumentAs()
        }
    }
    
    // MARK: - 导出动作
    
    @objc func exportToPDF(_ sender: Any) {
        Task {
            guard let vm = viewModel else { return }
            let exporter = SlideExporter(viewModel: vm)
            _ = await exporter.exportToPDF()
        }
    }
    
    @objc func exportToImages(_ sender: Any) {
        Task {
            guard let vm = viewModel else { return }
            let exporter = SlideExporter(viewModel: vm)
            _ = await exporter.exportToImages()
        }
    }
    
    // MARK: - 打印动作
    
    @objc func pageSetup(_ sender: Any) {
        let printInfo = NSPrintInfo.shared
        NSPageLayout.shared.runModal(for: NSApp.keyWindow, with: printInfo)
    }
    
    @objc func printDocument(_ sender: Any) {
        guard let vm = viewModel else { return }
        
        // 创建简单的打印视图
        let printView = NSHostingView(rootView: PrintPreviewView(viewModel: vm))
        
        // 打印操作
        let printOperation = NSPrintOperation(view: printView)
        printOperation.printInfo.horizontalPagination = .automatic
        printOperation.printInfo.verticalPagination = .automatic
        printOperation.printPanel.options = [.showsPaperSize, .showsOrientation]
        
        printOperation.run()
    }
    
    // MARK: - 编辑菜单动作
    
    @objc func showColorPanel(_ sender: Any) {
        NSColorPanel.shared.orderFront(nil)
    }
    
    // MARK: - 视图菜单动作
    
    @objc func zoomIn(_ sender: Any) {
        guard let vm = viewModel else { return }
        vm.zoomLevel = min(2.0, vm.zoomLevel + 0.1)
    }
    
    @objc func zoomOut(_ sender: Any) {
        guard let vm = viewModel else { return }
        vm.zoomLevel = max(0.5, vm.zoomLevel - 0.1)
    }
    
    @objc func actualSize(_ sender: Any) {
        guard let vm = viewModel else { return }
        vm.zoomLevel = 1.0
    }
    
    @objc func toggleRulers(_ sender: Any) {
        guard let vm = viewModel else { return }
        vm.showRulers.toggle()
    }
    
    @objc func toggleGrid(_ sender: Any) {
        guard let vm = viewModel else { return }
        vm.showGrid.toggle()
    }
    
    @objc func toggleNavigator(_ sender: Any) {
        // 这个动作需要在视图中实现
        NotificationCenter.default.post(name: NSNotification.Name("ToggleNavigator"), object: nil)
    }
    
    @objc func toggleInspector(_ sender: Any) {
        // 这个动作需要在视图中实现
        NotificationCenter.default.post(name: NSNotification.Name("ToggleInspector"), object: nil)
    }
    
    // MARK: - 幻灯片菜单动作
    
    @objc func addSlide(_ sender: Any) {
        viewModel?.addNewSlide()
    }
    
    @objc func deleteSlide(_ sender: Any) {
        viewModel?.deleteCurrentSlide()
    }
    
    @objc func duplicateSlide(_ sender: Any) {
        viewModel?.duplicateCurrentSlide()
    }
    
    @objc func nextSlide(_ sender: Any) {
        viewModel?.nextSlide()
    }
    
    @objc func previousSlide(_ sender: Any) {
        viewModel?.previousSlide()
    }
    
    @objc func applyStandardStyle(_ sender: Any) {
        guard let vm = viewModel else { return }
        vm.updateSlideStyle(.standard)
    }
    
    @objc func applyModernStyle(_ sender: Any) {
        guard let vm = viewModel else { return }
        vm.updateSlideStyle(.modern)
    }
    
    @objc func applyLightStyle(_ sender: Any) {
        guard let vm = viewModel else { return }
        vm.updateSlideStyle(.light)
    }
    
    // MARK: - 工具菜单动作
    
    @objc func showContentGenerator(_ sender: Any) {
        contentGeneratorWindowManager?.showContentGenerator()
    }
    
    // MARK: - 演示菜单动作
    
    @objc func startPresentation(_ sender: Any) {
        guard let vm = viewModel else { return }
        let launcher = PresentationLauncher(viewModel: vm)
        launcher.startPresentation()
    }
    
    @objc func startPresenterView(_ sender: Any) {
        guard let vm = viewModel else { return }
        let launcher = PresenterViewLauncher(viewModel: vm)
        launcher.launchPresenterMode()
    }
    
    @objc func toggleAutoPlay(_ sender: NSMenuItem) {
        sender.state = sender.state == .on ? .off : .on
    }
    
    @objc func setTransition(_ sender: NSMenuItem) {
        // 重置所有选项
        if let menu = sender.menu {
            for item in menu.items {
                item.state = .off
            }
        }
        
        // 设置选中状态
        sender.state = .on
    }
    
    @objc func recordPresentation(_ sender: Any) {
        // 录制功能将在后续版本实现
        let alert = NSAlert()
        alert.messageText = "功能即将推出"
        alert.informativeText = "录制演示功能将在未来版本中提供。"
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
    
    // MARK: - 帮助菜单动作
    
    @objc func openHelp(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://onlyslide.app/help")!)
    }
    
    @objc func checkForUpdates(_ sender: Any) {
        let alert = NSAlert()
        alert.messageText = "已是最新版本"
        alert.informativeText = "您正在使用OnlySlide的最新版本。"
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
    
    @objc func showKeyboardShortcuts(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://onlyslide.app/shortcuts")!)
    }
    
    @objc func showPreferences(_ sender: Any) {
        MacOSMenuBuilder.shared.showPreferences()
    }
}

// MARK: - 打印预览视图
struct PrintPreviewView: View {
    let viewModel: SlideEditorViewModel
    
    var body: some View {
        VStack {
            ForEach(viewModel.slides) { slide in
                VStack(alignment: .leading) {
                    Text(slide.title)
                        .font(.title)
                        .padding(.bottom, 10)
                    
                    Text(slide.content)
                        .font(.body)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .cornerRadius(0)
                .padding(.bottom, 20)
            }
        }
        .padding()
    }
}
#endif 