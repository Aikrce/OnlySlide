import Foundation

@objc(DocumentMetadata)
public final class DocumentMetadata: Codable, NSSecureCoding {
    public let tags: [String]
    public let documentDescription: String?
    public let lastViewedAt: Date?
    public let customProperties: [String: Any]
    
    public init(tags: [String] = [], documentDescription: String? = nil, lastViewedAt: Date? = nil, customProperties: [String: Any] = [:]) {
        self.tags = tags
        self.documentDescription = documentDescription
        self.lastViewedAt = lastViewedAt
        self.customProperties = customProperties
    }
    
    // MARK: - NSSecureCoding
    public static var supportsSecureCoding: Bool { true }
    
    public func encode(with coder: NSCoder) {
        coder.encode(tags, forKey: "tags")
        coder.encode(documentDescription, forKey: "documentDescription")
        coder.encode(lastViewedAt, forKey: "lastViewedAt")
        coder.encode(customProperties, forKey: "customProperties")
    }
    
    public required init?(coder: NSCoder) {
        self.tags = coder.decodeObject(of: [NSArray.self, NSString.self], forKey: "tags") as? [String] ?? []
        self.documentDescription = coder.decodeObject(of: NSString.self, forKey: "documentDescription") as String?
        self.lastViewedAt = coder.decodeObject(of: NSDate.self, forKey: "lastViewedAt") as Date?
        self.customProperties = coder.decodeObject(of: [NSDictionary.self, NSString.self, NSNumber.self, NSDate.self, NSData.self], forKey: "customProperties") as? [String: Any] ?? [:]
    }
    
    // MARK: - Codable
    private enum CodingKeys: String, CodingKey {
        case tags, documentDescription, lastViewedAt
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tags, forKey: .tags)
        try container.encode(documentDescription, forKey: .documentDescription)
        try container.encode(lastViewedAt, forKey: .lastViewedAt)
        // 自定义属性需要特殊处理，这里简单忽略
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tags = try container.decode([String].self, forKey: .tags)
        documentDescription = try container.decodeIfPresent(String.self, forKey: .documentDescription)
        lastViewedAt = try container.decodeIfPresent(Date.self, forKey: .lastViewedAt)
        customProperties = [:] // 解码时简单初始化
    }
    
    // MARK: - Description
    public var description: String {
        return "DocumentMetadata(tags: \(tags), description: \(String(describing: documentDescription)), lastViewedAt: \(String(describing: lastViewedAt)), customProperties: \(customProperties))"
    }
} 