import SwiftUI

/// 应用主页视图，显示最近文档和使用统计
struct HomeView: View {
    /// 最近文档列表
    let recentDocuments: [RecentDocument]
    /// 打开最近文档的回调
    let onOpenRecent: (RecentDocument) -> Void
    /// 导入文档回调
    let onImportDocument: () -> Void
    
    /// 环境变量：彩色方案
    @Environment(\.colorScheme) private var colorScheme
    
    // 若不提供参数则使用空数组和空闭包
    init(
        recentDocuments: [RecentDocument] = [],
        onOpenRecent: @escaping (RecentDocument) -> Void = { _ in },
        onImportDocument: @escaping () -> Void = {}
    ) {
        self.recentDocuments = recentDocuments
        self.onOpenRecent = onOpenRecent
        self.onImportDocument = onImportDocument
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 欢迎文本
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("欢迎使用 OnlySlide")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("从文档、音频或视频中快速创建出色的演示文稿")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 快速导入按钮
                quickImportMenu
            }
            .padding([.horizontal, .top])
            .padding(.bottom, 20)
            
            // 主内容区域
            if recentDocuments.isEmpty {
                emptyStateView
            } else {
                recentDocumentsView
            }
        }
        .background(colorScheme == .dark ? Color.black.opacity(0.1) : Color.white)
    }
    
    /// 快速导入菜单
    private var quickImportMenu: some View {
        Menu {
            Button(action: onImportDocument) {
                Label("导入文档", systemImage: "doc")
            }
            
            Button(action: onImportDocument) {
                Label("导入音频", systemImage: "waveform")
            }
            
            Button(action: onImportDocument) {
                Label("导入视频", systemImage: "film")
            }
        } label: {
            Text("快速导入")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundColor(.white)
                .background(Color.blue)
                .cornerRadius(8)
        }
    }
    
    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "doc.text.image")
                    .font(.system(size: 80))
                    .foregroundColor(.blue.opacity(0.8))
                
                Text("没有最近的文档")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("导入文档、音频或视频以创建一个新的演示文稿")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                
                Button(action: onImportDocument) {
                    Label("导入文件", systemImage: "plus")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.7))
    }
    
    /// 最近文档视图
    private var recentDocumentsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("最近文档")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // 添加一个分组选择控件
                Picker("分组", selection: .constant("日期")) {
                    Text("日期").tag("日期")
                    Text("类型").tag("类型")
                    Text("全部").tag("全部")
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            .padding(.horizontal)
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    // 今天分组
                    if let todayDocuments = groupDocumentsByDate(period: .today) {
                        documentGroup(title: "今天", documents: todayDocuments)
                    }
                    
                    // 本周分组
                    if let thisWeekDocuments = groupDocumentsByDate(period: .thisWeek) {
                        documentGroup(title: "本周", documents: thisWeekDocuments)
                    }
                    
                    // 更早分组
                    if let earlierDocuments = groupDocumentsByDate(period: .earlier) {
                        documentGroup(title: "更早", documents: earlierDocuments)
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    /// 文档分组视图
    private func documentGroup(title: String, documents: [RecentDocument]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 组标题
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.top, 6)
            
            // 组内文档
            ForEach(documents) { document in
                recentDocumentRow(document)
            }
        }
    }
    
    /// 最近文档行
    private func recentDocumentRow(_ document: RecentDocument) -> some View {
        Button(action: {
            onOpenRecent(document)
        }) {
            HStack(spacing: 12) {
                // 文档图标
                Image(systemName: getDocumentIcon(document.title))
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40)
                
                // 文档信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("上次打开: \(document.formattedDate)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 箭头图标
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(action: {
                // 复制文档功能
                print("复制文档: \(document.title)")
            }) {
                Label("复制", systemImage: "doc.on.doc")
            }
            
            Button(action: {
                // 导出文档功能
                print("导出文档: \(document.title)")
            }) {
                Label("导出", systemImage: "square.and.arrow.up")
            }
            
            Button(action: {
                // 删除文档功能
                print("删除文档: \(document.title)")
            }) {
                Label("删除", systemImage: "trash")
                    .foregroundColor(.red)
            }
        }
    }
    
    /// 根据文件名获取文档图标
    private func getDocumentIcon(_ filename: String) -> String {
        let extension = filename.components(separatedBy: ".").last?.lowercased() ?? ""
        
        switch extension {
        case "pdf":
            return "doc.text"
        case "doc", "docx":
            return "doc.richtext"
        case "txt", "md":
            return "doc.plaintext"
        case "mp3", "wav", "m4a":
            return "waveform"
        case "mp4", "mov", "m4v":
            return "film"
        default:
            return "doc"
        }
    }
    
    // MARK: - 分组功能
    
    /// 时间段枚举
    enum DatePeriod {
        case today
        case thisWeek
        case earlier
    }
    
    /// 按日期分组文档
    private func groupDocumentsByDate(period: DatePeriod) -> [RecentDocument]? {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        
        let filteredDocuments: [RecentDocument]
        
        switch period {
        case .today:
            // 今天的文档
            filteredDocuments = recentDocuments.filter { document in
                let documentDate = calendar.startOfDay(for: document.date)
                return documentDate == today
            }
        case .thisWeek:
            // 本周的文档（不包括今天）
            filteredDocuments = recentDocuments.filter { document in
                let documentDate = calendar.startOfDay(for: document.date)
                return documentDate >= weekStart && documentDate < today
            }
        case .earlier:
            // 更早的文档
            filteredDocuments = recentDocuments.filter { document in
                let documentDate = calendar.startOfDay(for: document.date)
                return documentDate < weekStart
            }
        }
        
        // 如果没有文档则返回nil
        return filteredDocuments.isEmpty ? nil : filteredDocuments
    }
}

/// 最近文档模型
struct RecentDocument: Identifiable, Codable {
    let id: UUID
    let title: String
    let date: Date
    let url: String?
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

/// 文档类型
enum DocumentType: String {
    case pdf = "pdf"
    case docx = "docx"
} 