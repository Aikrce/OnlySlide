import Foundation
import Combine
import OnlySlideCore

public class SlideViewModel: ObservableObject {
    private let slideService = SlideService()
    
    @Published public var slide: Slide
    @Published public var elements: [SlideElement] = []
    
    public init(slide: Slide) {
        self.slide = slide
    }
    
    public func addTextElement(content: String, at position: (x: Double, y: Double)) {
        let element = SlideElement(
            slideId: slide.id,
            type: .text,
            content: content,
            position: position,
            size: (width: 200, height: 100)
        )
        elements.append(element)
    }
    
    public func updateElement(_ element: SlideElement) {
        if let index = elements.firstIndex(where: { $0.id == element.id }) {
            elements[index] = element
        }
    }
} 