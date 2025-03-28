import CoreData
import Foundation
import os.log

/// 定义实体和领域模型之间的转换
public protocol EntityModelConvertible {
    /// 关联的领域模型类型
    associatedtype DomainModelType
    
    /// 将实体转换为数据字典
    func toDomain() -> DomainModelType
    
    /// 从数据字典更新实体
    func update(from domainModel: DomainModelType)
}

/// 定义领域模型和实体之间的转换
public protocol DomainModelConvertible {
    /// 关联的实体类型
    associatedtype EntityType: NSManagedObject
    
    /// 将领域模型转换为实体
    func toEntity(in context: NSManagedObjectContext) -> EntityType
    
    /// 创建或更新实体
    func updateOrCreate(in context: NSManagedObjectContext) -> EntityType
}

/// 用于CoreData ID查找的协议
public protocol CoreDataIdentifiable {
    /// ID类型
    associatedtype ID: Equatable
    
    /// 实体或模型的唯一标识符
    var id: ID { get }
}

/// 扩展NSManagedObject提供查找功能
extension NSManagedObject {
    /// 根据ID查找实体
    public static func find<T: NSManagedObject>(byID id: UUID, in context: NSManagedObjectContext) -> T? where T: CoreDataIdentifiable, T.ID == UUID {
        let fetchRequest = NSFetchRequest<T>(entityName: String(describing: T.self))
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            os_log("查找实体时出错: %{public}@", log: OSLog(subsystem: "com.onlyslide.coredata", category: "coreData"), type: .error, error.localizedDescription)
            return nil
        }
    }
} 