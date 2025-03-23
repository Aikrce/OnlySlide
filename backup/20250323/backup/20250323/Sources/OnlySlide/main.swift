// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

print("开始执行完整备份...")

// 获取用户文档目录作为备份根目录
let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let backupRoot = documentDirectory.appendingPathComponent("OnlySlide/Backups")

do {
    // 创建备份ID（使用时间戳）
    let dateFormatter = ISO8601DateFormatter()
    let timestamp = dateFormatter.string(from: Date())
    let backupId = "Release_\(timestamp)"
    
    // 创建备份目录
    let backupPath = backupRoot.appendingPathComponent(backupId)
    try FileManager.default.createDirectory(at: backupPath, withIntermediateDirectories: true)
    
    // 创建子目录
    let sourcePath = backupPath.appendingPathComponent("Source")
    let databasePath = backupPath.appendingPathComponent("Database")
    let assetsPath = backupPath.appendingPathComponent("Assets")
    
    try FileManager.default.createDirectory(at: sourcePath, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: databasePath, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: assetsPath, withIntermediateDirectories: true)
    
    // 获取当前目录
    let currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    
    // 备份源代码
    print("正在备份源代码...")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
    process.arguments = ["-r", sourcePath.appendingPathComponent("source.zip").path, "."]
    process.currentDirectoryURL = currentDirectoryURL
    try process.run()
    process.waitUntilExit()
    
    // 备份数据库（如果存在）
    print("正在备份数据库...")
    let dbPath = "Core/Data/CoreData/OnlySlide.sqlite"
    if FileManager.default.fileExists(atPath: dbPath) {
        try FileManager.default.copyItem(
            at: URL(fileURLWithPath: dbPath),
            to: databasePath.appendingPathComponent("OnlySlide.sqlite")
        )
    }
    
    // 备份资源文件（如果存在）
    print("正在备份资源文件...")
    let assetsDir = "Assets"
    if FileManager.default.fileExists(atPath: assetsDir) {
        let assetsProcess = Process()
        assetsProcess.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        assetsProcess.arguments = ["-r", assetsPath.appendingPathComponent("assets.zip").path, assetsDir]
        assetsProcess.currentDirectoryURL = currentDirectoryURL
        try assetsProcess.run()
        assetsProcess.waitUntilExit()
    }
    
    // 生成备份记录
    let backupInfo = """
    Backup ID: \(backupId)
    Timestamp: \(timestamp)
    Location: \(backupPath.path)
    Components:
    - Source Code
    - Database
    - Assets
    """
    
    try backupInfo.write(
        to: backupPath.appendingPathComponent("backup_info.txt"),
        atomically: true,
        encoding: .utf8
    )
    
    print("备份完成！")
    print("备份位置：\(backupPath.path)")
} catch {
    print("备份失败：\(error.localizedDescription)")
    exit(1)
}
