import Foundation

public protocol FileManaging {
    func openFile() -> URL?
    func saveFile(data: Data, at url: URL) -> Bool
    func getDocumentsDirectory() -> URL
}

#if os(iOS)
public class IOSFileManager: FileManaging {
    public init() {}
    
    public func openFile() -> URL? {
        // iOS特定实现
        return nil // 实际实现应返回文件URL
    }
    
    public func saveFile(data: Data, at url: URL) -> Bool {
        // iOS特定实现
        return true // 实际实现应返回保存结果
    }
    
    public func getDocumentsDirectory() -> URL {
        // 返回iOS文档目录
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}
#elseif os(macOS)
public class MacOSFileManager: FileManaging {
    public init() {}
    
    public func openFile() -> URL? {
        // macOS特定实现
        return nil // 实际实现应返回文件URL
    }
    
    public func saveFile(data: Data, at url: URL) -> Bool {
        // macOS特定实现
        return true // 实际实现应返回保存结果
    }
    
    public func getDocumentsDirectory() -> URL {
        // 返回macOS文档目录
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}
#endif

// 平台无关的工厂方法
public func createFileManager() -> FileManaging {
    #if os(iOS)
    return IOSFileManager()
    #elseif os(macOS)
    return MacOSFileManager()
    #endif
} 