import Foundation

public protocol DocumentExporting {
    func exportAsPDF(document: Document) -> Data?
    func exportAsImages(document: Document) -> [Data]?
    func exportAsPresentation(document: Document, format: PresentationFormat) -> Data?
}

public enum PresentationFormat {
    case powerPoint
    case keynote
    case pdf
    case images
} 