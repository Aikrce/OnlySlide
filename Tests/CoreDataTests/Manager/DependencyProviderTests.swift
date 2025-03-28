#if canImport(XCTest)
import XCTest
@testable import CoreDataModule

/// 依赖注册表单元测试
final class DependencyProviderTests: XCTestCase {
    
    // MARK: - Properties
    
    /// 测试对象
    var registry: DependencyRegistry!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        registry = DependencyRegistry()
        // 清空注册表中的默认注册，以便测试
        registry.reset()
        registry.containers.removeAll()
    }
    
    override func tearDown() {
        registry = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    /// 测试基本依赖注册与解析
    func testBasicRegistrationAndResolution() {
        // 注册服务
        registry.register { "Test String" }
        registry.register { 42 }
        
        // 解析服务
        let stringValue: String = registry.resolve()
        let intValue: Int = registry.resolve()
        
        // 验证结果
        XCTAssertEqual(stringValue, "Test String")
        XCTAssertEqual(intValue, 42)
    }
    
    /// 测试共享依赖的单例行为
    func testSharedDependencies() {
        // 创建一个可变类，用于测试是否返回相同实例
        final class MutableService {
            var value = 0
        }
        
        // 注册为共享依赖
        registry.registerShared { MutableService() }
        
        // 获取两个实例
        let service1: MutableService = registry.resolve()
        let service2: MutableService = registry.resolve()
        
        // 修改第一个实例
        service1.value = 100
        
        // 验证第二个实例也被修改（因为它们是同一个实例）
        XCTAssertEqual(service2.value, 100)
    }
    
    /// 测试非共享依赖的行为
    func testNonSharedDependencies() {
        // 创建一个可变类，用于测试是否返回不同实例
        final class MutableService {
            var value = 0
        }
        
        // 注册为非共享依赖
        registry.register { MutableService() }
        
        // 获取两个实例
        let service1: MutableService = registry.resolve()
        let service2: MutableService = registry.resolve()
        
        // 修改第一个实例
        service1.value = 100
        
        // 验证第二个实例没有被修改（因为它们是不同的实例）
        XCTAssertEqual(service2.value, 0)
    }
    
    /// 测试按类型注册依赖
    func testTypeBasedRegistration() {
        // 定义协议
        protocol TestService {
            func getValue() -> String
        }
        
        // 实现协议
        struct RealTestService: TestService {
            func getValue() -> String {
                return "Real Service"
            }
        }
        
        // 按协议类型注册
        registry.register(TestService.self) { RealTestService() }
        
        // 解析依赖
        let service: TestService = registry.resolve()
        
        // 验证结果
        XCTAssertEqual(service.getValue(), "Real Service")
    }
    
    /// 测试工厂注册
    func testFactoryRegistration() {
        // 创建工厂
        struct TestFactory: Factory {
            typealias Instance = String
            
            func create() -> String {
                return "Factory Created"
            }
        }
        
        // 注册工厂
        registry.register(factory: TestFactory())
        
        // 解析依赖
        let value: String = registry.resolve()
        
        // 验证结果
        XCTAssertEqual(value, "Factory Created")
    }
    
    /// 测试可选依赖解析
    func testOptionalResolution() {
        // 不注册依赖，尝试可选解析
        let value: String? = registry.optional()
        
        // 验证结果为nil
        XCTAssertNil(value)
        
        // 注册依赖后尝试可选解析
        registry.register { "Optional Value" }
        let registeredValue: String? = registry.optional()
        
        // 验证结果不为nil
        XCTAssertEqual(registeredValue, "Optional Value")
    }
    
    /// 测试重置注册表
    func testRegistryReset() {
        // 注册自定义依赖
        registry.register { "Custom Value" }
        
        // 重置注册表（这会添加默认注册项但清除自定义注册项）
        registry.reset()
        
        // 尝试解析自定义依赖，应该抛出错误
        XCTAssertThrowsError(try {
            let _: String = registry.resolve()
        }())
        
        // 但应该能解析默认注册的依赖
        XCTAssertNoThrow(try {
            let _: CoreDataResourceManager = registry.resolve()
        }())
    }
    
    /// 测试全局便捷函数
    @MainActor
    func testGlobalConvenienceFunctions() async {
        // 使用全局注册表
        DependencyRegistry.shared.register { "Global Value" }
        
        // 使用便捷函数解析
        let value: String = resolve()
        
        // 验证结果
        XCTAssertEqual(value, "Global Value")
    }
    
    /// 测试依赖覆盖
    func testDependencyOverride() {
        // 首先注册一个值
        registry.register { "Original Value" }
        
        // 然后用另一个值覆盖它
        registry.register { "Overridden Value" }
        
        // 解析依赖
        let value: String = registry.resolve()
        
        // 验证使用的是最新注册的值
        XCTAssertEqual(value, "Overridden Value")
    }
}

extension DependencyRegistry {
    // 为测试添加一个容器访问器
    var containers: [String: Any] {
        get { return Mirror(reflecting: self).descendant("containers") as? [String: Any] ?? [:] }
        set { }
    }
}
#endif 