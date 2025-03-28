import SwiftUI

struct MigrationConfirmationView: View {
    @ObservedObject var adapter: CoreDataUIAdapter
    @State private var showConfirmation = true
    @State private var databaseInfo: DatabaseInfo? = nil
    @State private var isCheckingMigration = false
    
    var body: some View {
        VStack {
            if showConfirmation {
                VStack(spacing: 20) {
                    Text("数据迁移确认")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("检测到需要迁移的数据，是否立即开始？")
                        .font(.body)
                    
                    if isCheckingMigration {
                        ProgressView("正在检查数据库...")
                    } else if let info = databaseInfo {
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(label: "数据库大小", value: info.formattedSize)
                            InfoRow(label: "当前版本", value: info.currentVersion)
                            InfoRow(label: "目标版本", value: info.targetVersion)
                            InfoRow(label: "估计时间", value: info.estimatedTime)
                            InfoRow(label: "迁移复杂度", value: info.complexityDescription)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("注意事项:")
                            .font(.caption)
                            .fontWeight(.bold)
                        
                        Text("• 迁移过程中请勿关闭应用")
                            .font(.caption)
                        
                        Text("• 所有数据将会自动备份")
                            .font(.caption)
                        
                        Text("• 如果出现问题将自动恢复")
                            .font(.caption)
                    }
                    .padding(.vertical)
                    
                    HStack(spacing: 20) {
                        Button("暂不迁移") {
                            showConfirmation = false
                        }
                        .buttonStyle(.bordered)
                        
                        Button("开始迁移") {
                            showConfirmation = false
                            Task {
                                await adapter.startMigration()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 10)
                .transition(.scale)
                .onAppear {
                    loadDatabaseInfo()
                }
            }
        }
        .animation(.spring(), value: showConfirmation)
    }
    
    private func loadDatabaseInfo() {
        isCheckingMigration = true
        Task {
            do {
                let info = try await adapter.getDatabaseInfo()
                await MainActor.run {
                    self.databaseInfo = info
                    self.isCheckingMigration = false
                }
            } catch {
                await MainActor.run {
                    self.databaseInfo = DatabaseInfo.defaultInfo
                    self.isCheckingMigration = false
                }
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

struct DatabaseInfo {
    let sizeInBytes: Int64
    let currentVersion: String
    let targetVersion: String
    let migrationComplexity: MigrationComplexity
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeInBytes)
    }
    
    var estimatedTime: String {
        switch migrationComplexity {
        case .simple:
            return "约 30 秒"
        case .moderate:
            return "约 1-2 分钟"
        case .complex:
            return "约 3-5 分钟"
        }
    }
    
    var complexityDescription: String {
        switch migrationComplexity {
        case .simple:
            return "简单"
        case .moderate:
            return "中等"
        case .complex:
            return "复杂"
        }
    }
    
    static let defaultInfo = DatabaseInfo(
        sizeInBytes: 0,
        currentVersion: "未知",
        targetVersion: "未知",
        migrationComplexity: .moderate
    )
}

enum MigrationComplexity {
    case simple
    case moderate
    case complex
} 