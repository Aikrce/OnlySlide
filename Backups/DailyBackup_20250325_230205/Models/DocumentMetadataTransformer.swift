import Foundation

@objc(DocumentMetadataTransformer)
final class DocumentMetadataTransformer: ValueTransformer {
    
    // MARK: - Transformer Registration
    
    override class func transformedValueClass() -> AnyClass {
        return NSData.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    static func register() {
        let transformer = DocumentMetadataTransformer()
        ValueTransformer.setValueTransformer(transformer, forName: NSValueTransformerName(rawValue: "DocumentMetadataTransformer"))
    }
    
    // MARK: - Transformation
    
    override func transformedValue(_ value: Any?) -> Any? {
        guard let metadata = value as? [String: Any] else {
            return nil
        }
        
        do {
            return try JSONSerialization.data(withJSONObject: metadata, options: [])
        } catch {
            print("无法转换文档元数据: \(error)")
            return nil
        }
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else {
            return nil
        }
        
        do {
            return try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            print("无法反向转换文档元数据: \(error)")
            return nil
        }
    }
} 