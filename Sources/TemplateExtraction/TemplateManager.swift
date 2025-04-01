import Foundation
import SwiftUI
import CoreData

/// 模板管理器类，负责模板的提取、存储和管理
public class TemplateManager: ObservableObject {
    /// 单例实例
    public static let shared = TemplateManager()
    
    /// 可用模板列表
    @Published public private(set) var templates: [TemplateInfo] = []
    /// 默认模板集的标识符列表
    @Published public private(set) var defaultTemplateIds: [String] = []
    /// 是否正在加载
    @Published public private(set) var isLoading: Bool = false
    /// 上次错误信息
    @Published public private(set) var lastError: String? = nil
    
    /// 模板存储位置
    private let templatesDirectoryURL: URL
    /// CoreData持久化容器
    private let persistentContainer: NSPersistentContainer
    
    /// 模板信息结构
    public struct TemplateInfo: Identifiable, Equatable {
        /// 模板唯一标识符
        public let id: String
        /// 模板名称
        public var name: String
        /// 模板预览图
        public var previewImage: UIImage?
        /// 模板文件URL
        public let fileURL: URL
        /// 模板详细信息
        public var details: PPTLayoutExtractor.PPTTemplateInfo?
        /// 是否为默认模板
        public var isDefault: Bool
        /// 创建时间
        public let creationDate: Date
        /// 最后修改时间
        public var modificationDate: Date
        
        public static func == (lhs: TemplateInfo, rhs: TemplateInfo) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    /// 模板提取选项
    public struct TemplateExtractionOptions {
        /// 是否提取预览图
        public var extractPreview: Bool
        /// 是否加载详细信息
        public var loadDetails: Bool
        /// 预览图最大宽度
        public var previewMaxWidth: CGFloat
        
        public init(extractPreview: Bool = true, loadDetails: Bool = false, previewMaxWidth: CGFloat = 400) {
            self.extractPreview = extractPreview
            self.loadDetails = loadDetails
            self.previewMaxWidth = previewMaxWidth
        }
    }
    
    /// 私有初始化方法
    private init() {
        // 设置模板存储目录
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.templatesDirectoryURL = appSupportURL.appendingPathComponent("Templates", isDirectory: true)
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: templatesDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        
        // 初始化CoreData
        self.persistentContainer = NSPersistentContainer(name: "TemplateModel")
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                print("Error loading persistent stores: \(error)")
            }
        }
        
        // 加载模板列表
        Task {
            await loadTemplates()
        }
    }
    
    // MARK: - 公共方法
    
    /// 加载所有模板
    /// - Parameter options: 模板加载选项
    public func loadTemplates(options: TemplateExtractionOptions = TemplateExtractionOptions()) async {
        await MainActor.run {
            isLoading = true
            lastError = nil
        }
        
        do {
            // 获取模板目录中的所有.pptx文件
            let fileURLs = try FileManager.default.contentsOfDirectory(at: templatesDirectoryURL, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension.lowercased() == "pptx" }
            
            // 从CoreData加载模板信息
            let context = persistentContainer.viewContext
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Template")
            let templates = try context.fetch(fetchRequest) as? [NSManagedObject] ?? []
            
            // 处理每个模板文件
            var templateInfos: [TemplateInfo] = []
            
            for fileURL in fileURLs {
                // 获取文件属性
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                let creationDate = attributes[.creationDate] as? Date ?? Date()
                let modificationDate = attributes[.modificationDate] as? Date ?? Date()
                
                // 生成ID
                let id = fileURL.deletingPathExtension().lastPathComponent
                
                // 检查是否已有记录
                let existingTemplate = templates.first { ($0.value(forKey: "id") as? String) == id }
                let isDefault = existingTemplate?.value(forKey: "isDefault") as? Bool ?? false
                let name = existingTemplate?.value(forKey: "name") as? String ?? fileURL.deletingPathExtension().lastPathComponent
                
                // 创建模板信息
                var templateInfo = TemplateInfo(
                    id: id,
                    name: name,
                    previewImage: nil,
                    fileURL: fileURL,
                    details: nil,
                    isDefault: isDefault,
                    creationDate: creationDate,
                    modificationDate: modificationDate
                )
                
                // 提取预览图
                if options.extractPreview {
                    do {
                        templateInfo.previewImage = try await PPTLayoutExtractor.extractPreviewImageFrom(
                            fileURL: fileURL,
                            maxWidth: options.previewMaxWidth
                        )
                    } catch {
                        print("Failed to extract preview for \(fileURL.lastPathComponent): \(error)")
                    }
                }
                
                // 加载详细信息
                if options.loadDetails {
                    do {
                        templateInfo.details = try await PPTLayoutExtractor.extractFrom(fileURL: fileURL)
                    } catch {
                        print("Failed to extract details for \(fileURL.lastPathComponent): \(error)")
                    }
                }
                
                templateInfos.append(templateInfo)
            }
            
            // 按修改日期排序
            templateInfos.sort { $0.modificationDate > $1.modificationDate }
            
            // 更新默认模板列表
            let defaultIds = templates
                .filter { ($0.value(forKey: "isDefault") as? Bool) == true }
                .compactMap { $0.value(forKey: "id") as? String }
            
            await MainActor.run {
                self.templates = templateInfos
                self.defaultTemplateIds = defaultIds
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.lastError = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    /// 加载模板的详细信息
    /// - Parameter templateId: 模板标识符
    /// - Returns: 模板的详细信息
    public func loadTemplateDetails(templateId: String) async throws -> PPTLayoutExtractor.PPTTemplateInfo {
        guard let templateIndex = templates.firstIndex(where: { $0.id == templateId }) else {
            throw NSError(domain: "TemplateManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Template not found"])
        }
        
        // 如果已有详细信息，则直接返回
        if let details = templates[templateIndex].details {
            return details
        }
        
        // 提取详细信息
        let fileURL = templates[templateIndex].fileURL
        let details = try await PPTLayoutExtractor.extractFrom(fileURL: fileURL)
        
        // 更新模板信息
        await MainActor.run {
            var updatedTemplate = templates[templateIndex]
            updatedTemplate.details = details
            templates[templateIndex] = updatedTemplate
        }
        
        return details
    }
    
    /// 导入PPT模板
    /// - Parameter fileURL: PPT文件URL
    /// - Returns: 导入的模板信息
    public func importTemplate(from fileURL: URL) async throws -> TemplateInfo {
        // 检查文件扩展名
        guard fileURL.pathExtension.lowercased() == "pptx" else {
            throw NSError(domain: "TemplateManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "只支持.pptx格式的PowerPoint文件"])
        }
        
        // 生成唯一ID
        let id = UUID().uuidString
        
        // 创建目标URL
        let targetURL = templatesDirectoryURL.appendingPathComponent("\(id).pptx")
        
        // 复制文件
        try FileManager.default.copyItem(at: fileURL, to: targetURL)
        
        // 提取模板信息
        let extractionOptions = TemplateExtractionOptions(extractPreview: true, loadDetails: true)
        let previewImage = try await PPTLayoutExtractor.extractPreviewImageFrom(fileURL: targetURL)
        let details = try await PPTLayoutExtractor.extractFrom(fileURL: targetURL)
        
        // 创建模板信息
        let now = Date()
        let templateInfo = TemplateInfo(
            id: id,
            name: details.name,
            previewImage: previewImage,
            fileURL: targetURL,
            details: details,
            isDefault: false,
            creationDate: now,
            modificationDate: now
        )
        
        // 保存到CoreData
        let context = persistentContainer.viewContext
        let template = NSEntityDescription.insertNewObject(forEntityName: "Template", into: context)
        template.setValue(id, forKey: "id")
        template.setValue(details.name, forKey: "name")
        template.setValue(false, forKey: "isDefault")
        template.setValue(now, forKey: "creationDate")
        template.setValue(now, forKey: "modificationDate")
        try context.save()
        
        // 更新模板列表
        await MainActor.run {
            templates.insert(templateInfo, at: 0)
        }
        
        return templateInfo
    }
    
    /// 更新模板
    /// - Parameters:
    ///   - templateId: 模板标识符
    ///   - templateInfo: 更新后的模板信息
    public func updateTemplate(templateId: String, with updatedDetails: PPTLayoutExtractor.PPTTemplateInfo) async throws {
        guard let templateIndex = templates.firstIndex(where: { $0.id == templateId }) else {
            throw NSError(domain: "TemplateManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Template not found"])
        }
        
        var template = templates[templateIndex]
        
        // 更新模板详细信息
        template.details = updatedDetails
        template.name = updatedDetails.name
        template.modificationDate = Date()
        
        // 更新CoreData
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Template")
        fetchRequest.predicate = NSPredicate(format: "id == %@", templateId)
        let result = try context.fetch(fetchRequest)
        if let managedObject = result.first as? NSManagedObject {
            managedObject.setValue(updatedDetails.name, forKey: "name")
            managedObject.setValue(Date(), forKey: "modificationDate")
            try context.save()
        }
        
        // 更新模板列表
        await MainActor.run {
            templates[templateIndex] = template
        }
    }
    
    /// 删除模板
    /// - Parameter templateId: 模板标识符
    public func deleteTemplate(templateId: String) async throws {
        guard let templateIndex = templates.firstIndex(where: { $0.id == templateId }) else {
            throw NSError(domain: "TemplateManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Template not found"])
        }
        
        let template = templates[templateIndex]
        
        // 删除文件
        try FileManager.default.removeItem(at: template.fileURL)
        
        // 从CoreData中删除
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Template")
        fetchRequest.predicate = NSPredicate(format: "id == %@", templateId)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        try context.execute(deleteRequest)
        try context.save()
        
        // 更新模板列表
        await MainActor.run {
            templates.remove(at: templateIndex)
            if template.isDefault {
                defaultTemplateIds.removeAll { $0 == templateId }
            }
        }
    }
    
    /// 设置模板为默认/非默认
    /// - Parameters:
    ///   - templateId: 模板标识符
    ///   - isDefault: 是否为默认模板
    public func setTemplateDefault(templateId: String, isDefault: Bool) async throws {
        guard let templateIndex = templates.firstIndex(where: { $0.id == templateId }) else {
            throw NSError(domain: "TemplateManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Template not found"])
        }
        
        // 更新CoreData
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Template")
        fetchRequest.predicate = NSPredicate(format: "id == %@", templateId)
        let result = try context.fetch(fetchRequest)
        if let managedObject = result.first as? NSManagedObject {
            managedObject.setValue(isDefault, forKey: "isDefault")
            try context.save()
        }
        
        // 更新模板列表
        await MainActor.run {
            var template = templates[templateIndex]
            template.isDefault = isDefault
            templates[templateIndex] = template
            
            if isDefault {
                if !defaultTemplateIds.contains(templateId) {
                    defaultTemplateIds.append(templateId)
                }
            } else {
                defaultTemplateIds.removeAll { $0 == templateId }
            }
        }
    }
}

// MARK: - 模板管理器视图

/// 模板库视图，用于展示和管理模板
public struct TemplateLibraryView: View {
    /// 模板管理器
    @StateObject private var templateManager = TemplateManager.shared
    /// 是否显示导入文件选择器
    @State private var showingImportPicker = false
    /// 导入的文件URL
    @State private var importFileURL: URL?
    /// 选中的模板ID
    @State private var selectedTemplateId: String?
    /// 模板视图模式
    @State private var viewMode: ViewMode = .grid
    /// 是否显示导入中状态
    @State private var isImporting = false
    /// 是否显示编辑视图
    @State private var showingEditView = false
    /// 是否显示删除确认
    @State private var showingDeleteConfirmation = false
    /// 要删除的模板ID
    @State private var templateToDelete: String?
    /// 是否显示错误提示
    @State private var showingErrorAlert = false
    /// 错误消息
    @State private var errorMessage = ""
    
    /// 视图模式
    public enum ViewMode {
        case grid
        case list
    }
    
    public var body: some View {
        NavigationView {
            VStack {
                // 视图模式切换
                Picker("视图模式", selection: $viewMode) {
                    Image(systemName: "square.grid.2x2").tag(ViewMode.grid)
                    Image(systemName: "list.bullet").tag(ViewMode.list)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // 模板列表
                if templateManager.isLoading {
                    ProgressView("加载模板中...")
                } else if templateManager.templates.isEmpty {
                    VStack {
                        Text("没有可用模板")
                            .font(.headline)
                            .padding()
                        
                        Button("导入模板") {
                            showingImportPicker = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView {
                        if viewMode == .grid {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 200))], spacing: 16) {
                                ForEach(templateManager.templates) { template in
                                    templateGridItem(for: template)
                                }
                            }
                            .padding()
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(templateManager.templates) { template in
                                    templateListItem(for: template)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("模板库")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingImportPicker = true
                    }) {
                        Label("导入", systemImage: "square.and.arrow.down")
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        refreshTemplates()
                    }) {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                }
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.init(filenameExtension: "pptx")!],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        importTemplate(from: url)
                    }
                case .failure(let error):
                    showError(message: "导入失败: \(error.localizedDescription)")
                }
            }
            .alert("导入失败", isPresented: $showingErrorAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("删除模板", isPresented: $showingDeleteConfirmation) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    if let id = templateToDelete {
                        deleteTemplate(id: id)
                    }
                }
            } message: {
                Text("确定要删除此模板吗？此操作无法撤销。")
            }
            .sheet(isPresented: $showingEditView) {
                if let selectedId = selectedTemplateId,
                   let templateIndex = templateManager.templates.firstIndex(where: { $0.id == selectedId }),
                   let details = templateManager.templates[templateIndex].details {
                    TemplateEditView(templateInfo: details) { updatedDetails in
                        updateTemplate(id: selectedId, details: updatedDetails)
                    }
                } else {
                    Text("无法加载模板")
                }
            }
        }
        .onAppear {
            refreshTemplates()
        }
    }
    
    // MARK: - 私有视图组件
    
    /// 网格视图中的模板项
    private func templateGridItem(for template: TemplateManager.TemplateInfo) -> some View {
        VStack {
            ZStack {
                if let previewImage = template.previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay(
                            Image(systemName: "doc.richtext")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        )
                }
                
                // 默认标记
                if template.isDefault {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .padding(6)
                                .background(Color.white.opacity(0.7))
                                .clipShape(Circle())
                                .padding(8)
                        }
                        Spacer()
                    }
                }
            }
            .frame(height: 100)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            
            Text(template.name)
                .font(.subheadline)
                .lineLimit(1)
                .padding(.top, 4)
            
            Text(template.modificationDate, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .contextMenu {
            templateContextMenu(for: template)
        }
        .onTapGesture {
            selectedTemplateId = template.id
            loadTemplateDetails(id: template.id)
        }
    }
    
    /// 列表视图中的模板项
    private func templateListItem(for template: TemplateManager.TemplateInfo) -> some View {
        HStack {
            // 预览图
            ZStack {
                if let previewImage = template.previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay(
                            Image(systemName: "doc.richtext")
                                .font(.title2)
                                .foregroundColor(.gray)
                        )
                }
            }
            .frame(width: 80, height: 45)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(template.name)
                        .font(.headline)
                    
                    if template.isDefault {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
                
                Text(template.modificationDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contextMenu {
            templateContextMenu(for: template)
        }
        .onTapGesture {
            selectedTemplateId = template.id
            loadTemplateDetails(id: template.id)
        }
    }
    
    /// 模板上下文菜单
    private func templateContextMenu(for template: TemplateManager.TemplateInfo) -> some View {
        Group {
            Button {
                selectedTemplateId = template.id
                loadTemplateDetails(id: template.id)
            } label: {
                Label("预览", systemImage: "eye")
            }
            
            Button {
                selectedTemplateId = template.id
                loadTemplateDetailsForEdit(id: template.id)
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            
            if template.isDefault {
                Button {
                    setTemplateDefault(id: template.id, isDefault: false)
                } label: {
                    Label("取消默认", systemImage: "star.slash")
                }
            } else {
                Button {
                    setTemplateDefault(id: template.id, isDefault: true)
                } label: {
                    Label("设为默认", systemImage: "star")
                }
            }
            
            Divider()
            
            Button(role: .destructive) {
                templateToDelete = template.id
                showingDeleteConfirmation = true
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
    
    // MARK: - 私有方法
    
    /// 刷新模板列表
    private func refreshTemplates() {
        Task {
            await templateManager.loadTemplates()
        }
    }
    
    /// 导入模板
    private func importTemplate(from url: URL) {
        isImporting = true
        
        Task {
            do {
                let _ = try await templateManager.importTemplate(from: url)
            } catch {
                await MainActor.run {
                    showError(message: "导入失败: \(error.localizedDescription)")
                    isImporting = false
                }
                return
            }
            
            await MainActor.run {
                isImporting = false
            }
        }
    }
    
    /// 加载模板详细信息
    private func loadTemplateDetails(id: String) {
        Task {
            do {
                let _ = try await templateManager.loadTemplateDetails(templateId: id)
                await MainActor.run {
                    showingEditView = false
                }
            } catch {
                showError(message: "加载模板详情失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 加载模板详细信息用于编辑
    private func loadTemplateDetailsForEdit(id: String) {
        Task {
            do {
                let _ = try await templateManager.loadTemplateDetails(templateId: id)
                await MainActor.run {
                    showingEditView = true
                }
            } catch {
                showError(message: "加载模板详情失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 更新模板
    private func updateTemplate(id: String, details: PPTLayoutExtractor.PPTTemplateInfo) {
        Task {
            do {
                try await templateManager.updateTemplate(templateId: id, with: details)
            } catch {
                showError(message: "更新模板失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 删除模板
    private func deleteTemplate(id: String) {
        Task {
            do {
                try await templateManager.deleteTemplate(templateId: id)
            } catch {
                showError(message: "删除模板失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 设置模板为默认/非默认
    private func setTemplateDefault(id: String, isDefault: Bool) {
        Task {
            do {
                try await templateManager.setTemplateDefault(templateId: id, isDefault: isDefault)
            } catch {
                showError(message: "设置默认模板失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 显示错误消息
    private func showError(message: String) {
        errorMessage = message
        showingErrorAlert = true
    }
}
