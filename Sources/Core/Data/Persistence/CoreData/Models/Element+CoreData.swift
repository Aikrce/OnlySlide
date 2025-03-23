import CoreData

@objc(Element)
public class Element: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var content: String?
    @NSManaged public var position: String?
    @NSManaged public var style: String?
    @NSManaged public var type: String?
    @NSManaged public var slide: Slide?
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
    }
}

extension Element {
    static var entityName: String {
        return String(describing: Element.self)
    }
    
    var elementType: ElementType {
        get {
            return ElementType(rawValue: type ?? "") ?? .text
        }
        set {
            type = newValue.rawValue
        }
    }
    
    var positionData: ElementPosition {
        get {
            guard let positionString = position,
                  let data = positionString.data(using: .utf8),
                  let position = try? JSONDecoder().decode(ElementPosition.self, from: data)
            else {
                return ElementPosition(x: 0, y: 0, width: 0, height: 0)
            }
            return position
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                position = string
            }
        }
    }
    
    var styleDict: [String: Any] {
        get {
            guard let styleString = style else { return [:] }
            return (try? JSONSerialization.jsonObject(with: styleString.data(using: .utf8) ?? Data(), options: []) as? [String: Any]) ?? [:]
        }
        set {
            if let data = try? JSONSerialization.data(withJSONObject: newValue, options: []),
               let string = String(data: data, encoding: .utf8) {
                style = string
            }
        }
    }
}

extension Element {
    static func fetchRequest() -> NSFetchRequest<Element> {
        return NSFetchRequest<Element>(entityName: "Element")
    }
} 