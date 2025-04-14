import SwiftUI

public struct AppTypography {
    public static let titleFont = Font.system(size: 28, weight: .bold)
    public static let subtitleFont = Font.system(size: 22, weight: .semibold)
    public static let bodyFont = Font.system(size: 16, weight: .regular)
    public static let captionFont = Font.system(size: 12, weight: .light)
    
    public struct TextStyles {
        public static func title(_ text: Text) -> some View {
            text
                .font(titleFont)
                .foregroundColor(AppColors.text)
        }
        
        public static func subtitle(_ text: Text) -> some View {
            text
                .font(subtitleFont)
                .foregroundColor(AppColors.text)
        }
        
        public static func body(_ text: Text) -> some View {
            text
                .font(bodyFont)
                .foregroundColor(AppColors.text)
        }
        
        public static func caption(_ text: Text) -> some View {
            text
                .font(captionFont)
                .foregroundColor(AppColors.text.opacity(0.8))
        }
    }
} 