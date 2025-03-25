import Foundation

/// Sendable兼容的线程安全属性包装器
/// 使用actor确保并发安全
@propertyWrapper
public struct ThreadSafeActor<Value: Sendable>: Sendable {
    /// 封装值的actor
    private actor Storage {
        var value: Value
        
        init(value: Value) {
            self.value = value
        }
        
        func get() -> Value {
            return value
        }
        
        func set(_ newValue: Value) {
            value = newValue
        }
        
        func modify<R>(_ modification: (inout Value) -> R) -> R {
            var mutableValue = value
            let result = modification(&mutableValue)
            value = mutableValue
            return result
        }
    }
    
    private let storage: Storage
    
    public init(wrappedValue: Value) {
        self.storage = Storage(value: wrappedValue)
    }
    
    public var wrappedValue: Value {
        get {
            Task {
                await storage.get()
            }.result.value ?? wrappedValue
        }
        set {
            Task {
                await storage.set(newValue)
            }
        }
    }
    
    public var projectedValue: ThreadSafeActor<Value> { self }
    
    /// 异步获取值
    public func get() async -> Value {
        await storage.get()
    }
    
    /// 异步设置值
    public func set(_ newValue: Value) async {
        await storage.set(newValue)
    }
    
    /// 异步修改值
    public func modify<R>(_ modification: (inout Value) -> R) async -> R {
        await storage.modify(modification)
    }
}

/// 使用AsyncResourceAccessor的安全访问
extension AsyncResourceAccessor {
    /// 安全修改值
    public func modify<T: Sendable>(_ action: @escaping (inout Resource) -> T) async -> T {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                var resourceCopy = self.resource
                let result = action(&resourceCopy)
                // 注意: 这个伪代码需要实际实现修改原始资源的逻辑
                // 实际使用中需要确保资源是可变的引用类型或使用actor
                continuation.resume(returning: result)
            }
        }
    }
}

/// 安全的锁扩展
extension NSLock {
    /// 用于在异步上下文中安全使用锁的辅助方法
    public func withLock<T>(_ action: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try action()
    }
    
    /// 异步使用锁
    public func withAsyncLock<T>(_ action: () async throws -> T) async rethrows -> T {
        // 在异步上下文中使用锁的替代方案
        // 注意: 实际上应该使用actor或AsyncResourceAccessor而不是NSLock
        lock()
        defer { unlock() }
        return try await action()
    }
} 