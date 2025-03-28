import Foundation

/// 表示同步数据的结构体
public struct SyncData: Equatable, Sendable {
    /// 存储的数据字典
    private let storage: [String: AnyCodable]
    
    /// 时间戳
    public var timestamp: Date {
        return storage["timestamp"]?.value as? Date ?? Date.distantPast
    }
    
    /// 初始化同步数据
    /// - Parameter dictionary: 原始字典数据
    public init(from dictionary: [String: Any]) {
        var convertedStorage: [String: AnyCodable] = [:]
        
        for (key, value) in dictionary {
            convertedStorage[key] = AnyCodable(value)
        }
        
        self.storage = convertedStorage
    }
    
    /// 使用键值对初始化
    public init(timestamp: Date = Date(), data: Any? = nil) {
        var dict: [String: AnyCodable] = ["timestamp": AnyCodable(timestamp)]
        if let data = data {
            dict["data"] = AnyCodable(data)
        }
        self.storage = dict
    }
    
    /// 转换为字典
    public func toDictionary() -> [String: Any] {
        var result: [String: Any] = [:]
        
        for (key, value) in storage {
            result[key] = value.value
        }
        
        return result
    }
    
    /// 获取值
    public func get(_ key: String) -> Any? {
        return storage[key]?.value
    }
    
    /// 获取字符串值
    public func getString(_ key: String) -> String? {
        return get(key) as? String
    }
    
    /// 获取日期值
    public func getDate(_ key: String) -> Date? {
        return get(key) as? Date
    }
    
    /// 获取数字值
    public func getNumber(_ key: String) -> NSNumber? {
        return get(key) as? NSNumber
    }
    
    /// 检查是否相等
    public static func == (lhs: SyncData, rhs: SyncData) -> Bool {
        // 检查键的数量
        guard lhs.storage.count == rhs.storage.count else {
            return false
        }
        
        // 比较每个键值对
        for (key, leftValue) in lhs.storage {
            guard let rightValue = rhs.storage[key] else {
                return false
            }
            
            if leftValue != rightValue {
                return false
            }
        }
        
        return true
    }
}

/// 用于包装任意值使其符合Sendable协议
public struct AnyCodable: Equatable, @unchecked Sendable {
    /// 存储的值
    let value: Any
    
    /// 初始化包装器
    public init(_ value: Any) {
        // 确保值是可序列化的基本类型或其集合
        // 这里我们接受所有类型，但在实际项目中应该限制为可Sendable的类型
        self.value = value
    }
    
    /// 检查是否相等
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        // 根据值的类型比较
        if let lhsDict = lhs.value as? [String: Any],
           let rhsDict = rhs.value as? [String: Any] {
            return lhsDict.isEqual(to: rhsDict)
        }
        
        if let lhsArray = lhs.value as? [Any],
           let rhsArray = rhs.value as? [Any] {
            // 简化的数组比较逻辑
            return lhsArray.count == rhsArray.count
        }
        
        return String(describing: lhs.value) == String(describing: rhs.value)
    }
} 