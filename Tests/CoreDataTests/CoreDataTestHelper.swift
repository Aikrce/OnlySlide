import XCTest
import CoreData
@testable import CoreDataModule

/// 用于CoreData测试的辅助类
final class CoreDataTestHelper {
    /// 使用内存存储创建测试持久化容器
    /// - Parameter modelName: 模型的名称
    /// - Returns: 配置好的测试容器
    static func createInMemoryContainer(modelName: String) -> NSPersistentContainer {
        // 尝试从测试Bundle获取模型
        guard let modelURL = Bundle.module.url(forResource: modelName, withExtension: "momd") else {
            fatalError("无法找到 \(modelName).momd 在测试Bundle中")
        }
        
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("无法从 \(modelName).momd 创建托管对象模型")
        }
        
        // 创建内存中的持久化容器
        let container = NSPersistentContainer(name: modelName, managedObjectModel: model)
        
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        
        var loadError: Error?
        container.loadPersistentStores { description, error in
            loadError = error
        }
        
        if let error = loadError {
            fatalError("加载持久化存储失败: \(error)")
        }
        
        return container
    }
    
    /// 清理测试数据库
    /// - Parameter context: 要清理的托管对象上下文
    static func cleanUpDatabase(context: NSManagedObjectContext) throws {
        // 获取所有实体
        guard let model = context.persistentStoreCoordinator?.managedObjectModel,
              let entities = model.entities as? [NSEntityDescription] else {
            return
        }
        
        // 对每个实体执行删除操作
        for entity in entities {
            guard let entityName = entity.name else { continue }
            
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            try context.persistentStoreCoordinator?.execute(deleteRequest, with: context)
        }
        
        // 保存更改
        if context.hasChanges {
            try context.save()
        }
    }
} 