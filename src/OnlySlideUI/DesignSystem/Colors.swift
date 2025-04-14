import SwiftUI

public struct AppColors {
    public static let primary = Color("PrimaryColor")
    public static let secondary = Color("SecondaryColor")
    public static let accent = Color("AccentColor")
    public static let background = Color("BackgroundColor")
    public static let text = Color("TextColor")
    
    // 提供动态颜色支持深色模式
    public static func dynamicColor(light: Color, dark: Color) -> Color {
        #if os(iOS)
        return Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #elseif os(macOS)
        return Color(NSColor { appearance in
            return appearance.name.rawValue.contains("Dark") ? NSColor(dark) : NSColor(light)
        })
        #else
        return light
        #endif
    }
} 