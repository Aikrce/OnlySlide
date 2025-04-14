import SwiftUI
import OnlySlideCore

public struct SlideView: View {
    @ObservedObject public var viewModel: SlideViewModel
    
    public init(viewModel: SlideViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack {
            Text(viewModel.slide.title)
                .font(.title)
            
            Text(viewModel.slide.content)
                .font(.body)
                .padding()
            
            // 在这里可以渲染幻灯片上的元素
            ForEach(viewModel.elements, id: \.id) { element in
                SlideElementView(element: element)
                    .position(x: element.position.x, y: element.position.y)
                    .frame(width: element.size.width, height: element.size.height)
            }
        }
        .padding()
    }
}

struct SlideElementView: View {
    let element: SlideElement
    
    var body: some View {
        switch element.type {
        case .text:
            Text(element.content)
        case .image:
            Text("图片占位符")
        case .chart:
            Text("图表占位符")
        case .video:
            Text("视频占位符")
        }
    }
} 