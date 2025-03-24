import Foundation

// 执行备份的主函数
@main
struct Backup {
    static func main() async throws {
        print("开始执行完整备份...")
        
        // 创建备份管理器
        let manager = CoreBackupManager.shared
        
        do {
            // 执行完整备份
            try await manager.performBackup(
                type: .release,
                components: [.source, .database, .assets]
            )
            
            print("备份完成！")
            print("备份位置：\(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Backups"))")
        } catch {
            print("备份失败：\(error)")
            throw error
        }
    }
} 