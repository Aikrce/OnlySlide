#if canImport(XCTest)
import XCTest
@testable import OnlySlideUI

final class OnlySlideUITests: XCTestCase {
    func testExample() throws {
        // 在这里编写您的测试并使用 XCTest API 来检查预期条件
        XCTAssert(true, "基本测试通过")
    }
}
#else
import Testing
@testable import OnlySlideUI

final class OnlySlideUITests {
    func run() {
        testExample()
    }
    
    func testExample() {
        // 在这里编写您的测试并使用 TestSupport API 来检查预期条件
        TestSupport.assert(true, "基本测试通过")
    }
}
#endif
