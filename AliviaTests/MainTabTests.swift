import XCTest
@testable import Alivia

final class MainTabTests: XCTestCase {
    func testTheTechnicianKeepsTheOrdersTabs() {
        XCTAssertEqual([.home, .orders, .schedule, .profile], MainTab.tabs(for: .technician))
    }

    func testTheCaregiverGetsTheTabsOfTheDocumentation() {
        XCTAssertEqual([.home, .devices, .alerts, .agenda, .profile], MainTab.tabs(for: .caregiver))
    }
}
