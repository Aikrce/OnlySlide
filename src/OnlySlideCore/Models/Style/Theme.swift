import Foundation

public struct Theme {
    public var id: UUID
    public var name: String
    public var primaryColor: String
    public var secondaryColor: String
    public var fontFamily: String
    
    public init(id: UUID = UUID(), name: String, primaryColor: String, secondaryColor: String, fontFamily: String) {
        self.id = id
        self.name = name
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.fontFamily = fontFamily
    }
} 