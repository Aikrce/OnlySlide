import Foundation

public enum ElementType {
    case text
    case image
    case chart
    case video
}

public struct SlideElement {
    public var id: UUID
    public var slideId: UUID
    public var type: ElementType
    public var content: String
    public var position: (x: Double, y: Double)
    public var size: (width: Double, height: Double)
    
    public init(id: UUID = UUID(), slideId: UUID, type: ElementType, content: String, position: (x: Double, y: Double), size: (width: Double, height: Double)) {
        self.id = id
        self.slideId = slideId
        self.type = type
        self.content = content
        self.position = position
        self.size = size
    }
} 