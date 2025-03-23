import Foundation

public struct ThemeModel: Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let primaryColor: String
    public let secondaryColor: String
    public let backgroundColor: String
    public let textColor: String
    public let fontFamily: String
    public let fontSize: Double
    
    public init(id: UUID = UUID(),
                name: String,
                primaryColor: String,
                secondaryColor: String,
                backgroundColor: String,
                textColor: String,
                fontFamily: String,
                fontSize: Double) {
        self.id = id
        self.name = name
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.fontFamily = fontFamily
        self.fontSize = fontSize
    }
} 