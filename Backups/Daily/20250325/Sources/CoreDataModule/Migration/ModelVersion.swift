import Foundation

/// 表示模型版本的结构体
public struct ModelVersion: Comparable, Sendable {
    /// 主版本号
    public let major: Int
    /// 次版本号
    public let minor: Int
    /// 修订版本号
    public let patch: Int
    
    /// 版本标识符，如"V1_2_3"表示版本1.2.3
    public let identifier: String
    
    /// 源版本（用于迁移）
    public var sourceVersion: ModelVersion {
        return self
    }
    
    /// 目标版本（用于迁移）
    public var destinationVersion: ModelVersion {
        return self
    }
    
    /// 版本描述
    public var description: String {
        return "v\(major).\(minor).\(patch)"
    }
    
    /// 从版本字符串创建模型版本
    /// - Parameter versionString: 版本字符串，格式为"V{major}_{minor}_{patch}"
    public init?(versionString: String) {
        self.identifier = versionString
        
        // 解析版本号
        let components = versionString.components(separatedBy: "_")
        
        // 确保格式正确
        guard components.count >= 2,
              components[0].hasPrefix("V"),
              let majorString = components[0].dropFirst().description,
              let major = Int(majorString) else {
            return nil
        }
        
        self.major = major
        
        // 解析次版本号
        if components.count >= 2, let minor = Int(components[1]) {
            self.minor = minor
        } else {
            self.minor = 0
        }
        
        // 解析修订版本号
        if components.count >= 3, let patch = Int(components[2]) {
            self.patch = patch
        } else {
            self.patch = 0
        }
    }
    
    /// 从模型版本标识符集合中创建模型版本
    /// - Parameter versionIdentifiers: 版本标识符集合
    public init?(versionIdentifiers: Set<String>) {
        // 查找以V开头的标识符
        guard let versionString = versionIdentifiers.first(where: { $0.hasPrefix("V") }) else {
            return nil
        }
        
        // 调用主构造函数
        guard let version = ModelVersion(versionString: versionString) else {
            return nil
        }
        
        self.major = version.major
        self.minor = version.minor
        self.patch = version.patch
        self.identifier = version.identifier
    }
    
    /// 从AnyHashable类型的版本标识符集合创建模型版本
    /// - Parameter versionIdentifiers: AnyHashable类型的版本标识符集合
    public init?(versionIdentifiers: Set<AnyHashable>) {
        // 检查是否为空集合
        guard !versionIdentifiers.isEmpty else { return nil }
        
        // 将AnyHashable转换为String，使用更安全的方式
        var stringIdentifiers = Set<String>()
        for identifier in versionIdentifiers {
            if let stringId = identifier as? String {
                stringIdentifiers.insert(stringId)
            }
        }
        
        // 确保转换后的集合不为空
        guard !stringIdentifiers.isEmpty else { return nil }
        
        // 查找以V开头的标识符
        guard let versionString = stringIdentifiers.first(where: { $0.hasPrefix("V") }) else {
            return nil
        }
        
        // 调用主构造函数
        guard let version = ModelVersion(versionString: versionString) else {
            return nil
        }
        
        self.major = version.major
        self.minor = version.minor
        self.patch = version.patch
        self.identifier = version.identifier
    }

    /// 从URL创建模型版本
    /// - Parameter url: 模型文件的URL
    /// - Returns: 模型版本，如果无法从URL中提取版本信息则返回nil
    public static func from(url: URL) -> ModelVersion? {
        // 获取文件名
        let fileName = url.lastPathComponent
        
        // 尝试从文件名中提取版本信息
        // 例如: "Model_V1_0_0.mom" 或 "ModelV1_0_0.xcdatamodeld"
        
        // 查找版本标识符（以V开头，后面跟数字和下划线）
        let pattern = "V\\d+(?:_\\d+)*"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        
        let fileNameString = fileName as NSString
        let matches = regex.matches(in: fileName, options: [], range: NSRange(location: 0, length: fileNameString.length))
        
        guard let match = matches.first else {
            return nil
        }
        
        let versionString = fileNameString.substring(with: match.range)
        return ModelVersion(versionString: versionString)
    }
    
    /// 创建版本序列
    /// - Parameters:
    ///   - from: 起始版本
    ///   - to: 结束版本
    /// - Returns: 版本序列，包含起始和结束版本之间的所有版本
    public static func sequence(from: ModelVersion, to: ModelVersion) -> [ModelVersion] {
        // 如果起始版本大于或等于结束版本，返回空数组
        if from >= to {
            return []
        }
        
        // 简单情况：只考虑主版本号和次版本号
        var result: [ModelVersion] = []
        
        // 主版本号相同的情况
        if from.major == to.major {
            // 次版本号差距为1的情况，直接返回结束版本
            if to.minor - from.minor == 1 {
                return [to]
            }
            
            // 否则，生成中间的所有次版本
            for minor in (from.minor + 1)...to.minor {
                let versionString = "V\(from.major)_\(minor)_0"
                if let version = ModelVersion(versionString: versionString) {
                    result.append(version)
                }
            }
            return result
        }
        
        // 主版本号不同的情况
        // 1. 添加当前主版本的最高次版本
        let currentMajorLatestMinor = 99 // 假设次版本号不会超过99
        let currentMajorLatestVersionString = "V\(from.major)_\(currentMajorLatestMinor)_0"
        if let currentMajorLatestVersion = ModelVersion(versionString: currentMajorLatestVersionString) {
            result.append(currentMajorLatestVersion)
        }
        
        // 2. 添加中间的所有主版本
        for major in (from.major + 1)..<to.major {
            let versionString = "V\(major)_0_0"
            if let version = ModelVersion(versionString: versionString) {
                result.append(version)
            }
        }
        
        // 3. 添加目标主版本的所有次版本
        for minor in 0...to.minor {
            let versionString = "V\(to.major)_\(minor)_0"
            if let version = ModelVersion(versionString: versionString) {
                result.append(version)
            }
        }
        
        return result
    }
    
    // MARK: - Comparable
    
    public static func < (lhs: ModelVersion, rhs: ModelVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        
        return lhs.patch < rhs.patch
    }
}