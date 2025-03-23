import Foundation

@objc(DocumentMetadata)
public class DocumentMetadata: NSObject, NSSecureCoding {
    public let tags: [String]
    public let documentDescription: String?
    public let lastViewedAt: Date?
    public let customProperties: [String: Any]
    
    public init(tags: [String] = [], documentDescription: String? = nil, lastViewedAt: Date? = nil, customProperties: [String: Any] = [:]) {
        self.tags = tags
        self.documentDescription = documentDescription
        self.lastViewedAt = lastViewedAt
        self.customProperties = customProperties
        super.init()
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
        super.init()
    }
    
    // MARK: - NSObject
    public override var description: String {
        return "DocumentMetadata(tags: \(tags), description: \(String(describing: documentDescription)), lastViewedAt: \(String(describing: lastViewedAt)), customProperties: \(customProperties))"
    }
} 