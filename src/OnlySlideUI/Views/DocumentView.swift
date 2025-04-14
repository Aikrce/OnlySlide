import SwiftUI
import OnlySlideCore

public struct DocumentView: View {
    @ObservedObject public var viewModel: DocumentViewModel
    
    public init(viewModel: DocumentViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack {
            Text(viewModel.document.title)
                .font(.largeTitle)
            
            Text("屏幕尺寸: \(viewModel.getScreenSize().width) x \(viewModel.getScreenSize().height)")
                .font(.subheadline)
        }
        .padding()
    }
} 