import Foundation
import CoreData

public class CoreDataManager {
    public static let shared = CoreDataManager()
    
    private init() {}
    
    // 这里应该添加CoreData的实际实现
    // 例如持久化容器、上下文和模型加载等
    
    public func saveContext() {
        // 保存CoreData上下文
        print("保存CoreData上下文")
    }
} 