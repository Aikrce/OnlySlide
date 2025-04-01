import Foundation

/// 文档分析结果存储服务
public class DocumentAnalysisStorage {
    /// 共享实例
    public static let shared = DocumentAnalysisStorage()
    
    /// 存储位置
    private let storageDirectory: URL
    
    /// 存储文件名
    private let storageFilename = "document_analysis_results.json"
    
    /// 已保存的结果
    private var savedResults: [DocumentAnalysisResult] = []
    
    /// 私有初始化方法
    private init() {
        // 获取应用文档目录
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // 创建存储目录
        storageDirectory = documentsDirectory.appendingPathComponent("OnlySlide/DocumentAnalysis", isDirectory: true)
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        
        // 从磁盘加载已保存的结果
        loadFromDisk()
    }
    
    /// 存储目录URL
    public var directoryURL: URL {
        return storageDirectory
    }
    
    /// 存储文件URL
    private var storageFileURL: URL {
        return storageDirectory.appendingPathComponent(storageFilename)
    }
    
    /// 保存分析结果
    /// - Parameter result: 要保存的分析结果
    /// - Returns: 操作是否成功
    @discardableResult
    public func save(result: DocumentAnalysisResult) -> Bool {
        // 检查是否已存在相同ID的结果
        if let index = savedResults.firstIndex(where: { $0.id == result.id }) {
            // 更新现有结果
            savedResults[index] = result
        } else {
            // 添加新结果
            savedResults.append(result)
        }
        
        // 保存到磁盘
        return saveToDisk()
    }
    
    /// 删除分析结果
    /// - Parameter id: 要删除的结果ID
    /// - Returns: 操作是否成功
    @discardableResult
    public func delete(withID id: UUID) -> Bool {
        // 检查是否存在该ID的结果
        guard let index = savedResults.firstIndex(where: { $0.id == id }) else {
            return false
        }
        
        // 删除结果
        savedResults.remove(at: index)
        
        // 保存到磁盘
        return saveToDisk()
    }
    
    /// 获取所有保存的分析结果
    /// - Returns: 保存的分析结果数组
    public func getAllResults() -> [DocumentAnalysisResult] {
        return savedResults
    }
    
    /// 获取特定ID的分析结果
    /// - Parameter id: 结果ID
    /// - Returns: 找到的分析结果，如果不存在则返回nil
    public func getResult(withID id: UUID) -> DocumentAnalysisResult? {
        return savedResults.first(where: { $0.id == id })
    }
    
    /// 清除所有保存的结果
    /// - Returns: 操作是否成功
    @discardableResult
    public func clearAll() -> Bool {
        savedResults.removeAll()
        return saveToDisk()
    }
    
    // MARK: - 私有辅助方法
    
    /// 将结果保存到磁盘
    private func saveToDisk() -> Bool {
        do {
            // 将结果编码为JSON数据
            let encoder = JSONEncoder()
            let data = try encoder.encode(savedResults)
            
            // 写入文件
            try data.write(to: storageFileURL)
            return true
        } catch {
            print("保存分析结果失败: \(error)")
            return false
        }
    }
    
    /// 从磁盘加载结果
    private func loadFromDisk() {
        do {
            // 检查文件是否存在
            guard FileManager.default.fileExists(atPath: storageFileURL.path) else {
                savedResults = []
                return
            }
            
            // 读取文件数据
            let data = try Data(contentsOf: storageFileURL)
            
            // 解码JSON数据
            let decoder = JSONDecoder()
            savedResults = try decoder.decode([DocumentAnalysisResult].self, from: data)
        } catch {
            print("加载分析结果失败: \(error)")
            savedResults = []
        }
    }
}

// MARK: - 存储扩展方法
public extension DocumentAnalysisResult {
    /// 保存当前分析结果
    func save() -> Bool {
        return DocumentAnalysisStorage.shared.save(result: self)
    }
    
    /// 从存储中删除当前分析结果
    func delete() -> Bool {
        return DocumentAnalysisStorage.shared.delete(withID: id)
    }
}