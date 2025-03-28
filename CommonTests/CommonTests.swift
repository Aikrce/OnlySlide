// IMPORTANT: This file should ONLY belong to the CommonTests target
// and should NOT be included in the main OnlySlide application target.
// Please check File Inspector (Option+Command+1) to ensure correct Target Membership.

#if canImport(XCTest)
import XCTest
@testable import Common

final class CommonTests: XCTestCase {
    override func setUpWithError() throws {
        // 测试前的设置代码
    }

    override func tearDownWithError() throws {
        // 测试后的清理代码
    }

    func testExample() throws {
        // 这里添加测试用例
        XCTAssert(true, "基础测试通过")
    }
}
#else
import Common
import Testing

final class CommonTests {
    func run() {
        // 使用自定义断言
        TestSupport.assert(true, "基础测试通过")
    }
}
#endif 