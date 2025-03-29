import Foundation

/// 迁移结果
public struct MigrationResult: Equatable, Sendable {
    /// 源版本
    public let sourceVersion: ModelVersion
    
    /// 目标版本
    public let destinationVersion: ModelVersion
    
    /// 迁移开始时间
    public let startTime: Date
    
    /// 迁移结束时间
    public let endTime: Date
    
    /// 迁移耗时（秒）
    public var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
    
    /// 是否执行了备份
    public let backupCreated: Bool
    
    /// 备份路径（如果有）
    public let backupPath: URL?
    
    /// 创建迁移结果
    /// - Parameters:
    ///   - sourceVersion: 源版本
    ///   - destinationVersion: 目标版本
    ///   - startTime: 迁移开始时间
    ///   - endTime: 迁移结束时间
    ///   - backupCreated: 是否创建了备份
    ///   - backupPath: 备份路径（如果有）
    public init(sourceVersion: ModelVersion, 
                destinationVersion: ModelVersion,
                startTime: Date,
                endTime: Date,
                backupCreated: Bool = false,
                backupPath: URL? = nil) {
        self.sourceVersion = sourceVersion
        self.destinationVersion = destinationVersion
        self.startTime = startTime
        self.endTime = endTime
        self.backupCreated = backupCreated
        self.backupPath = backupPath
    }
    
    /// 创建成功的迁移结果
    /// - Parameters:
    ///   - sourceVersion: 源版本
    ///   - destinationVersion: 目标版本
    ///   - startTime: 迁移开始时间
    ///   - backupCreated: 是否创建了备份
    ///   - backupPath: 备份路径
    /// - Returns: 迁移结果
    public static func success(
        sourceVersion: ModelVersion,
        destinationVersion: ModelVersion,
        startTime: Date,
        backupCreated: Bool = false,
        backupPath: URL? = nil
    ) -> MigrationResult {
        return MigrationResult(
            sourceVersion: sourceVersion,
            destinationVersion: destinationVersion,
            startTime: startTime,
            endTime: Date(),
            backupCreated: backupCreated,
            backupPath: backupPath
        )
    }
    
    /// 实现Equatable协议
    public static func == (lhs: MigrationResult, rhs: MigrationResult) -> Bool {
        return lhs.sourceVersion == rhs.sourceVersion &&
               lhs.destinationVersion == rhs.destinationVersion &&
               lhs.startTime == rhs.startTime &&
               lhs.endTime == rhs.endTime &&
               lhs.backupCreated == rhs.backupCreated &&
               lhs.backupPath == rhs.backupPath
    }
} 