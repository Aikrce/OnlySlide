import Foundation
import CoreData
import Combine

/// 提供并发安全的工具函数和类型，以减少对 @preconcurrency 属性的依赖
/// 这个文件包含了帮助改进并发安全性的各种实用工具

// MARK: - 异步安全的任务执行器

/// 在主线程上安全执行任务的工具函数
@MainActor
public func executeOnMainActor<T>(_ work: @MainActor () throws -> T) rethrows -> T {
    return try work()
}

/// 在后台线程上安全执行任务并返回到主线程
public func executeInBackground<T: Sendable>(
    _ work: @escaping @Sendable () async throws -> T
) async throws -> T {
    return try await Task.detached(priority: .userInitiated) {
        return try await work()
    }.value
}

// MARK: - 线程安全的包装器

/// 提供线程安全访问的属性包装器
@propertyWrapper
public final class ThreadSafe<Value: Sendable> {
    private let lock = NSLock()
    private var value: Value
    
    public init(wrappedValue: Value) {
        self.value = wrappedValue
    }
    
    public var wrappedValue: Value {
        get {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            value = newValue
        }
    }
    
    public var projectedValue: ThreadSafe<Value> {
        return self
    }
    
    /// 安全地执行对值的修改
    public func mutate(_ mutation: (inout Value) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        mutation(&value)
    }
}

// MARK: - 安全的发布者扩展

extension Publisher where Self.Failure == Never {
    /// 安全地处理值类型发布者的更新
    public func assignNoRetain<Root: AnyObject>(
        to keyPath: ReferenceWritableKeyPath<Root, Self.Output>,
        on object: Root
    ) -> AnyCancellable {
        return sink { [weak object] value in
            DispatchQueue.main.async {
                object?[keyPath: keyPath] = value
            }
        }
    }
}

// MARK: - 并发安全的资源访问

/// 抽象表示线程安全的资源访问器
public protocol ResourceAccessProtocol {
    associatedtype Resource
    
    /// 读取资源
    func read<T>(_ action: (Resource) throws -> T) rethrows -> T
    
    /// 写入/修改资源
    func write<T>(_ action: (inout Resource) throws -> T) rethrows -> T
}

/// 基于互斥锁的资源访问实现
public final class MutexProtectedResource<Resource>: ResourceAccessProtocol {
    private let lock = NSLock()
    private var resource: Resource
    
    public init(_ resource: Resource) {
        self.resource = resource
    }
    
    public func read<T>(_ action: (Resource) throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try action(resource)
    }
    
    public func write<T>(_ action: (inout Resource) throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try action(&resource)
    }
}

// MARK: - 线程安全集合

/// 线程安全的字典
public final class ConcurrentDictionary<Key: Hashable, Value> {
    private var storage = [Key: Value]()
    private let lock = NSLock()
    
    public init() {}
    
    public subscript(key: Key) -> Value? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storage[key]
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            storage[key] = newValue
        }
    }
    
    public func removeValue(forKey key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        return storage.removeValue(forKey: key)
    }
    
    public func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }
    
    public var keys: [Key] {
        lock.lock()
        defer { lock.unlock() }
        return Array(storage.keys)
    }
    
    public var values: [Value] {
        lock.lock()
        defer { lock.unlock() }
        return Array(storage.values)
    }
    
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }
}

// MARK: - 异步资源访问

/// 安全地异步访问资源的辅助器
public final class AsyncResourceAccessor<Resource: Sendable> {
    private let resource: Resource
    private let queue = DispatchQueue(label: "com.onlyslide.asyncresource", attributes: .concurrent)
    
    public init(_ resource: Resource) {
        self.resource = resource
    }
    
    /// 异步读取资源
    public func read<T: Sendable>(_ action: @escaping (Resource) -> T) async -> T {
        return await withCheckedContinuation { continuation in
            queue.async {
                let result = action(self.resource)
                continuation.resume(returning: result)
            }
        }
    }
    
    /// 异步写入资源（使用屏障确保写入安全）
    public func write<T: Sendable>(_ action: @escaping (Resource) -> T) async -> T {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                let result = action(self.resource)
                continuation.resume(returning: result)
            }
        }
    }
}

// MARK: - 安全的Core Data访问

/// 安全地访问 Core Data 上下文
@MainActor
public struct CoreDataContextAccessor {
    private let context: NSManagedObjectContext
    
    public init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    /// 在主线程上下文中执行操作
    public func perform<T>(_ block: (NSManagedObjectContext) throws -> T) async throws -> T {
        // 如果已经在主线程，直接执行
        if Thread.isMainThread {
            return try block(context)
        }
        
        // 否则，确保在主线程上执行
        return try await MainActor.run {
            return try block(context)
        }
    }
    
    /// 安全地异步在主线程上下文中执行操作
    public func performAsync<T: Sendable>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await MainActor.run {
            return try block(context)
        }
    }
}

// MARK: - 隔离的Core Data存储

/// 管理独立的持久化存储容器
public actor IsolatedPersistentContainer {
    private let container: NSPersistentContainer
    
    public init(name: String, managedObjectModel: NSManagedObjectModel) {
        self.container = NSPersistentContainer(name: name, managedObjectModel: managedObjectModel)
    }
    
    public init(name: String) {
        self.container = NSPersistentContainer(name: name)
    }
    
    /// 加载持久化存储
    public func loadPersistentStores() async throws -> [NSPersistentStoreDescription] {
        return try await withCheckedThrowingContinuation { continuation in
            container.loadPersistentStores { descriptions, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: container.persistentStoreDescriptions)
                }
            }
        }
    }
    
    /// 获取视图上下文（在主线程上使用）
    public func viewContext() -> NSManagedObjectContext {
        return container.viewContext
    }
    
    /// 创建新的后台上下文
    public func newBackgroundContext() -> NSManagedObjectContext {
        return container.newBackgroundContext()
    }
    
    /// 在后台上下文执行块
    public func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            container.performBackgroundTask { context in
                do {
                    let result = try block(context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - 使用说明

/*
 这些工具的使用方式：
 
 1. 使用 ThreadSafe 包装器保护并发访问的属性：
 
 ```swift
 struct MyManager {
     @ThreadSafe private var cache: [String: Data] = [:]
     
     func getData(for key: String) -> Data? {
         return cache[key]
     }
     
     func setData(_ data: Data, for key: String) {
         cache[key] = data
     }
 }
 ```
 
 2. 使用 ConcurrentDictionary 替代需要线程安全的字典：
 
 ```swift
 struct CacheManager {
     private let cache = ConcurrentDictionary<String, Data>()
     
     func getData(for key: String) -> Data? {
         return cache[key]
     }
     
     func setData(_ data: Data, for key: String) {
         cache[key] = data
     }
 }
 ```
 
 3. 使用 AsyncResourceAccessor 安全地异步访问资源：
 
 ```swift
 struct ResourceManager {
     private let accessor = AsyncResourceAccessor(MyResource())
     
     func readResource() async -> String {
         return await accessor.read { resource in
             return resource.getData()
         }
     }
     
     func updateResource(with data: String) async {
         await accessor.write { resource in
             resource.update(with: data)
         }
     }
 }
 ```
 
 4. 使用 CoreDataContextAccessor 安全地访问 Core Data 上下文：
 
 ```swift
 struct DataManager {
     private let contextAccessor: CoreDataContextAccessor
     
     init(context: NSManagedObjectContext) {
         self.contextAccessor = CoreDataContextAccessor(context: context)
     }
     
     func fetchEntities() async throws -> [MyEntity] {
         return try await contextAccessor.performAsync { context in
             let request = MyEntity.fetchRequest()
             return try context.fetch(request) as! [MyEntity]
         }
     }
 }
 ```
 
 5. 使用 IsolatedPersistentContainer 管理隔离的持久化存储：
 
 ```swift
 class DataStore {
     private let container = IsolatedPersistentContainer(name: "MyModel")
     
     func initialize() async throws {
         try await container.loadPersistentStores()
     }
     
     func fetchData() async throws -> [MyEntity] {
         return try await container.performBackgroundTask { context in
             let request = MyEntity.fetchRequest()
             return try context.fetch(request) as! [MyEntity]
         }
     }
 }
 ```
 */ 