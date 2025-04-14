import Foundation

public struct Style {
    public var id: UUID
    public var name: String
    public var fontSize: Double
    public var fontWeight: String
    public var alignment: String
    
    public init(id: UUID = UUID(), name: String, fontSize: Double, fontWeight: String, alignment: String) {
        self.id = id
        self.name = name
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.alignment = alignment
    }
} 