import XCTest
@testable import Hyperfocus

final class FocusStoreTests: XCTestCase {
    private func makeStore() -> FocusStore { FocusStore() }

    func test_addApp_appendsToBlockedApps() {
        let store = makeStore()
        let app = BlockedApp(id: UUID(), bundleIdentifier: "com.test.App", displayName: "Test")
        store.addApp(app)
        XCTAssertEqual(store.blockedApps.count, 1)
        XCTAssertEqual(store.blockedApps.first?.bundleIdentifier, "com.test.App")
    }

    func test_removeApp_removesFromBlockedApps() {
        let store = makeStore()
        let app = BlockedApp(id: UUID(), bundleIdentifier: "com.test.App", displayName: "Test")
        store.addApp(app)
        store.removeApp(id: app.id)
        XCTAssertTrue(store.blockedApps.isEmpty)
    }

    func test_removeApp_unknownID_doesNothing() {
        let store = makeStore()
        store.removeApp(id: UUID())
        XCTAssertTrue(store.blockedApps.isEmpty)
    }

    func test_addSite_appendsToBlockedSites() {
        let store = makeStore()
        let site = BlockedSite(id: UUID(), domain: "linkedin.com")
        store.addSite(site)
        XCTAssertEqual(store.blockedSites.count, 1)
        XCTAssertEqual(store.blockedSites.first?.domain, "linkedin.com")
    }

    func test_removeSite_removesFromBlockedSites() {
        let store = makeStore()
        let site = BlockedSite(id: UUID(), domain: "linkedin.com")
        store.addSite(site)
        store.removeSite(id: site.id)
        XCTAssertTrue(store.blockedSites.isEmpty)
    }

    func test_addApp_firesOnStateChanged() {
        let store = makeStore()
        var callCount = 0
        store.onStateChanged = { callCount += 1 }
        store.addApp(BlockedApp(id: UUID(), bundleIdentifier: "com.x", displayName: "X"))
        XCTAssertEqual(callCount, 1)
    }

    func test_removeApp_firesOnStateChanged() {
        let store = makeStore()
        let app = BlockedApp(id: UUID(), bundleIdentifier: "com.x", displayName: "X")
        store.addApp(app)
        var callCount = 0
        store.onStateChanged = { callCount += 1 }
        store.removeApp(id: app.id)
        XCTAssertEqual(callCount, 1)
    }

    func test_addSite_firesOnStateChanged() {
        let store = makeStore()
        var callCount = 0
        store.onStateChanged = { callCount += 1 }
        store.addSite(BlockedSite(id: UUID(), domain: "test.com"))
        XCTAssertEqual(callCount, 1)
    }

    func test_removeSite_firesOnStateChanged() {
        let store = makeStore()
        let site = BlockedSite(id: UUID(), domain: "test.com")
        store.addSite(site)
        var callCount = 0
        store.onStateChanged = { callCount += 1 }
        store.removeSite(id: site.id)
        XCTAssertEqual(callCount, 1)
    }

    func test_init_withBlocklist_populatesState() {
        let app = BlockedApp(id: UUID(), bundleIdentifier: "com.kakao.KakaoTalk", displayName: "카카오톡")
        let site = BlockedSite(id: UUID(), domain: "linkedin.com")
        let store = FocusStore(blocklist: FocusBlocklist(blockedApps: [app], blockedSites: [site]))
        XCTAssertEqual(store.blockedApps.count, 1)
        XCTAssertEqual(store.blockedSites.count, 1)
    }
}
