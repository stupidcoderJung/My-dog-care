import XCTest
@testable import MyDogCareApp

final class PlaceholderTests: XCTestCase {
    func testExampleUserInitials() {
        let user = ClerkUser(id: "1", fullName: "Sparky McDog", email: nil)
        XCTAssertEqual(user.initials, "SM")
    }
}
