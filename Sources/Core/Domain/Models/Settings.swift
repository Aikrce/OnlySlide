import Foundation

public struct Settings: Codable {
    public var theme: String
    public var language: String
    public var notifications: Bool
    public var autoSave: Bool
    
    public init(theme: String = "light",
                language: String = "en",
                notifications: Bool = true,
                autoSave: Bool = true) {
        self.theme = theme
        self.language = language
        self.notifications = notifications
        self.autoSave = autoSave
    }
} 