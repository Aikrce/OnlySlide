import CoreData
import Foundation

// MARK: - NSManagedObject Extensions

extension NSManagedObject {
    
    /// 实体名称
    public static var entityName: String {
        return String(describing: self)
    }
    
    /// 创建请求
    public static func fetchRequest<T: NSFetchRequestResult>() -> NSFetchRequest<T> {
        return NSFetchRequest<T>(entityName: entityName)
    }
    
    /// 创建请求（具体类型）
    public static func createFetchRequest<T: NSManagedObject>() -> NSFetchRequest<T> where T: NSFetchRequestResult {
        return NSFetchRequest<T>(entityName: entityName)
    }
    
    /// 根据ID获取对象
    public static func find(byID id: UUID, context: NSManagedObjectContext) -> Self? {
        let request = NSFetchRequest<Self>(entityName: entityName)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("查找ID为 \(id) 的对象失败: \(error)")
            return nil
        }
    }
    
    /// 获取所有对象
    public static func findAll(in context: NSManagedObjectContext) -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        
        do {
            return try context.fetch(request)
        } catch {
            print("获取所有对象失败: \(error)")
            return []
        }
    }
}

// MARK: - CDDocument Extensions

extension CDDocument {
    
    /// 创建新文档
    public static func create(in context: NSManagedObjectContext, title: String, content: String? = nil) -> CDDocument {
        let document = CDDocument(context: context)
        document.title = title
        document.content = content
        document.id = UUID()
        document.createdAt = Date()
        document.updatedAt = Date()
        return document
    }
    
    /// 查找标题包含指定字符串的文档
    public static func find(withTitle title: String, in context: NSManagedObjectContext) -> [CDDocument] {
        let request = NSFetchRequest<CDDocument>(entityName: entityName)
        request.predicate = NSPredicate(format: "title CONTAINS[cd] %@", title)
        
        do {
            return try context.fetch(request)
        } catch {
            print("查找标题包含 \(title) 的文档失败: \(error)")
            return []
        }
    }
    
    /// 获取最近的文档
    public static func findRecent(limit: Int = 10, in context: NSManagedObjectContext) -> [CDDocument] {
        let request = NSFetchRequest<CDDocument>(entityName: entityName)
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        request.fetchLimit = limit
        
        do {
            return try context.fetch(request)
        } catch {
            print("获取最近 \(limit) 个文档失败: \(error)")
            return []
        }
    }
}

// MARK: - CDSlide Extensions

extension CDSlide {
    
    /// 创建新幻灯片
    public static func create(in context: NSManagedObjectContext, document: CDDocument? = nil, index: Int32) -> CDSlide {
        let slide = CDSlide(context: context)
        slide.document = document
        slide.index = index
        return slide
    }
    
    /// 获取文档的所有幻灯片
    public static func find(forDocument document: CDDocument, in context: NSManagedObjectContext) -> [CDSlide] {
        let request = NSFetchRequest<CDSlide>(entityName: entityName)
        request.predicate = NSPredicate(format: "document == %@", document)
        request.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("获取文档 \(document.id) 的幻灯片失败: \(error)")
            return []
        }
    }
} 