# Focus Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 세션 running 중에만 차단 앱을 강제 종료하고 Chrome 탭을 닫는 Focus Mode를 추가한다.

**Architecture:** `FocusBlocker`(Service)가 실제 차단을 수행하고, `FocusStore`(Store)가 차단 목록을 보유한다. `TimerStore`에 `onBlockingStart`/`onBlockingStop` 콜백을 추가해 running ↔ non-running 전환 시 `FocusBlocker.activate()`/`deactivate()`를 호출한다. 설정은 Popover에 새로 추가되는 Focus 화면에서 관리하며, `state.json`에 영구 저장된다.

**Tech Stack:** Swift/SwiftUI, AppKit(NSWorkspace 알림), Foundation(Process + /usr/bin/osascript), Observation, XCTest

---

## 파일 맵

| 작업 | 경로 | 상태 |
|------|------|------|
| Task 1 | `Hyperfocus/Models/FocusBlocklist.swift` | 신규 |
| Task 1 | `Hyperfocus/Models/PersistedState.swift` | 수정 |
| Task 1 | `HyperfocusTests/PersistenceTests.swift` | 수정 (테스트 추가) |
| Task 2 | `Hyperfocus/Stores/FocusStore.swift` | 신규 |
| Task 2 | `HyperfocusTests/FocusStoreTests.swift` | 신규 |
| Task 3 | `Hyperfocus/Stores/TimerStore.swift` | 수정 |
| Task 3 | `HyperfocusTests/TimerStoreTests.swift` | 수정 (테스트 추가) |
| Task 4 | `Hyperfocus/Info.plist` | 수정 |
| Task 5 | `Hyperfocus/Services/FocusBlocker.swift` | 신규 |
| Task 6 | `Hyperfocus/HyperfocusApp.swift` | 수정 |
| Task 7 | `Hyperfocus/Views/Focus/FocusScreen.swift` | 신규 |
| Task 7 | `Hyperfocus/Views/Focus/AppPickerView.swift` | 신규 |
| Task 8 | `Hyperfocus/Views/PopoverRoot.swift` | 수정 |
| Task 8 | `Hyperfocus/Views/Timer/TimerScreen.swift` | 수정 |
| Task 8 | `Hyperfocus/Views/Timer/TimerControls.swift` | 수정 |

---

## Task 1: FocusBlocklist 모델 + PersistedState 하위 호환 업데이트

**Files:**
- Create: `Hyperfocus/Models/FocusBlocklist.swift`
- Modify: `Hyperfocus/Models/PersistedState.swift`
- Modify: `HyperfocusTests/PersistenceTests.swift`

- [ ] **Step 1: `FocusBlocklist.swift` 생성**

```swift
// Hyperfocus/Models/FocusBlocklist.swift
import Foundation

struct BlockedApp: Codable, Identifiable, Equatable {
    var id: UUID
    var bundleIdentifier: String  // "com.kakao.KakaoTalk"
    var displayName: String       // "카카오톡"
}

struct BlockedSite: Codable, Identifiable, Equatable {
    var id: UUID
    var domain: String            // "linkedin.com"
}

struct FocusBlocklist: Codable, Equatable {
    var blockedApps: [BlockedApp]
    var blockedSites: [BlockedSite]

    init(blockedApps: [BlockedApp] = [], blockedSites: [BlockedSite] = []) {
        self.blockedApps = blockedApps
        self.blockedSites = blockedSites
    }
}
```

- [ ] **Step 2: Xcode 프로젝트에 파일 등록**

```bash
cd /Users/jwchoi/Desktop/hyperfocus
ruby -e "
require 'xcodeproj'
proj = Xcodeproj::Project.open('Hyperfocus.xcodeproj')
target = proj.targets.find { |t| t.name == 'Hyperfocus' }
group = proj.main_group['Hyperfocus']['Models']
ref = group.new_reference('FocusBlocklist.swift')
target.source_build_phase.add_file_reference(ref)
proj.save
puts 'Added FocusBlocklist.swift to Hyperfocus target'
"
```

- [ ] **Step 3: `PersistedState.swift`에 `focusBlocklist` 추가 (기존 JSON 하위 호환)**

기존 `state.json`에 `focusBlocklist` 키가 없어도 깨지지 않도록 커스텀 `init(from:)`을 사용한다.

```swift
// Hyperfocus/Models/PersistedState.swift
import Foundation

struct PersistedState: Codable {
    var schemaVersion: Int
    var currentDay: Day
    var pastDays: [Day]
    var activeSession: Session?
    var focusBlocklist: FocusBlocklist

    init(
        schemaVersion: Int = 1,
        currentDay: Day = Day(),
        pastDays: [Day] = [],
        activeSession: Session? = nil,
        focusBlocklist: FocusBlocklist = FocusBlocklist()
    ) {
        self.schemaVersion = schemaVersion
        self.currentDay = currentDay
        self.pastDays = pastDays
        self.activeSession = activeSession
        self.focusBlocklist = focusBlocklist
    }

    // focusBlocklist가 없는 기존 JSON을 읽을 때 빈 목록으로 폴백
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        currentDay = try c.decode(Day.self, forKey: .currentDay)
        pastDays = try c.decode([Day].self, forKey: .pastDays)
        activeSession = try c.decodeIfPresent(Session.self, forKey: .activeSession)
        focusBlocklist = try c.decodeIfPresent(FocusBlocklist.self, forKey: .focusBlocklist) ?? FocusBlocklist()
    }
}
```

- [ ] **Step 4: 실패 테스트 작성 — `PersistenceTests.swift`에 2개 케이스 추가**

파일 끝(마지막 `}` 바로 앞)에 다음 테스트를 추가한다.

```swift
    func test_roundTrip_preservesFocusBlocklist() {
        let p = Persistence(fileURL: tempURL)
        let app = BlockedApp(id: UUID(), bundleIdentifier: "com.kakao.KakaoTalk", displayName: "카카오톡")
        let site = BlockedSite(id: UUID(), domain: "linkedin.com")
        let state = PersistedState(focusBlocklist: FocusBlocklist(blockedApps: [app], blockedSites: [site]))
        p.saveNow(state)
        let loaded = p.load()
        XCTAssertEqual(loaded.focusBlocklist.blockedApps.count, 1)
        XCTAssertEqual(loaded.focusBlocklist.blockedApps.first?.bundleIdentifier, "com.kakao.KakaoTalk")
        XCTAssertEqual(loaded.focusBlocklist.blockedSites.count, 1)
        XCTAssertEqual(loaded.focusBlocklist.blockedSites.first?.domain, "linkedin.com")
    }

    func test_loadingOldStateWithoutFocusBlocklist_returnsEmptyBlocklist() {
        // focusBlocklist 키가 없는 구버전 JSON 시뮬레이션
        let dayID = UUID().uuidString
        let oldJSON = """
        {
          "schemaVersion": 1,
          "currentDay": {"id": "\(dayID)", "startedAt": "2026-05-29T00:00:00Z", "sessions": []},
          "pastDays": []
        }
        """.data(using: .utf8)!
        try! oldJSON.write(to: tempURL)
        let p = Persistence(fileURL: tempURL)
        let state = p.load()
        XCTAssertTrue(state.focusBlocklist.blockedApps.isEmpty)
        XCTAssertTrue(state.focusBlocklist.blockedSites.isEmpty)
    }
```

- [ ] **Step 5: 테스트 실패 확인**

```bash
cd /Users/jwchoi/Desktop/hyperfocus
xcodebuild test \
  -project Hyperfocus.xcodeproj \
  -scheme Hyperfocus \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:HyperfocusTests/PersistenceTests/test_roundTrip_preservesFocusBlocklist \
  2>&1 | grep -E "PASSED|FAILED|error:" | tail -10
```

Expected: `FAILED` (FocusBlocklist 타입 없음)

- [ ] **Step 6: Step 1~3 코드 반영 후 테스트 통과 확인**

```bash
xcodebuild test \
  -project Hyperfocus.xcodeproj \
  -scheme Hyperfocus \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:HyperfocusTests/PersistenceTests \
  2>&1 | grep -E "PASSED|FAILED|error:" | tail -10
```

Expected: 모든 PersistenceTests `PASSED`

- [ ] **Step 7: 커밋**

```bash
git add Hyperfocus/Models/FocusBlocklist.swift \
        Hyperfocus/Models/PersistedState.swift \
        Hyperfocus.xcodeproj/project.pbxproj \
        HyperfocusTests/PersistenceTests.swift
git commit -m "feat: add FocusBlocklist models and backward-compatible PersistedState"
```

---

## Task 2: FocusStore + 단위 테스트

**Files:**
- Create: `Hyperfocus/Stores/FocusStore.swift`
- Create: `HyperfocusTests/FocusStoreTests.swift`

- [ ] **Step 1: 실패 테스트 파일 생성**

```swift
// HyperfocusTests/FocusStoreTests.swift
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
}
```

- [ ] **Step 2: 테스트 파일을 Xcode 프로젝트에 등록**

```bash
cd /Users/jwchoi/Desktop/hyperfocus
ruby -e "
require 'xcodeproj'
proj = Xcodeproj::Project.open('Hyperfocus.xcodeproj')
target = proj.targets.find { |t| t.name == 'HyperfocusTests' }
group = proj.main_group['HyperfocusTests']
ref = group.new_reference('FocusStoreTests.swift')
target.source_build_phase.add_file_reference(ref)
proj.save
puts 'Added FocusStoreTests.swift to HyperfocusTests target'
"
```

- [ ] **Step 3: 테스트 실패 확인**

```bash
xcodebuild test \
  -project Hyperfocus.xcodeproj \
  -scheme Hyperfocus \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:HyperfocusTests/FocusStoreTests \
  2>&1 | grep -E "PASSED|FAILED|error:" | tail -10
```

Expected: `FAILED` (FocusStore 타입 없음)

- [ ] **Step 4: `FocusStore.swift` 구현**

```swift
// Hyperfocus/Stores/FocusStore.swift
import Foundation
import os.log

private let logger = Logger(subsystem: "com.hyperfocus", category: "FocusStore")

@Observable
final class FocusStore {
    private(set) var blockedApps: [BlockedApp]
    private(set) var blockedSites: [BlockedSite]

    var onStateChanged: (() -> Void)?

    init(blocklist: FocusBlocklist = FocusBlocklist()) {
        self.blockedApps = blocklist.blockedApps
        self.blockedSites = blocklist.blockedSites
    }

    func addApp(_ app: BlockedApp) {
        blockedApps.append(app)
        logger.info("Blocked app added: \(app.bundleIdentifier)")
        onStateChanged?()
    }

    func removeApp(id: UUID) {
        blockedApps.removeAll { $0.id == id }
        logger.info("Blocked app removed: \(id)")
        onStateChanged?()
    }

    func addSite(_ site: BlockedSite) {
        blockedSites.append(site)
        logger.info("Blocked site added: \(site.domain)")
        onStateChanged?()
    }

    func removeSite(id: UUID) {
        blockedSites.removeAll { $0.id == id }
        logger.info("Blocked site removed: \(id)")
        onStateChanged?()
    }
}
```

- [ ] **Step 5: Xcode 프로젝트에 등록**

```bash
cd /Users/jwchoi/Desktop/hyperfocus
ruby -e "
require 'xcodeproj'
proj = Xcodeproj::Project.open('Hyperfocus.xcodeproj')
target = proj.targets.find { |t| t.name == 'Hyperfocus' }
group = proj.main_group['Hyperfocus']['Stores']
ref = group.new_reference('FocusStore.swift')
target.source_build_phase.add_file_reference(ref)
proj.save
puts 'Added FocusStore.swift to Hyperfocus target'
"
```

- [ ] **Step 6: 테스트 통과 확인**

```bash
xcodebuild test \
  -project Hyperfocus.xcodeproj \
  -scheme Hyperfocus \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:HyperfocusTests/FocusStoreTests \
  2>&1 | grep -E "PASSED|FAILED|error:" | tail -10
```

Expected: 모든 FocusStoreTests `PASSED`

- [ ] **Step 7: 커밋**

```bash
git add Hyperfocus/Stores/FocusStore.swift \
        Hyperfocus.xcodeproj/project.pbxproj \
        HyperfocusTests/FocusStoreTests.swift
git commit -m "feat: add FocusStore with CRUD and persistence callback"
```

---

## Task 3: TimerStore — 차단 콜백 추가

**Files:**
- Modify: `Hyperfocus/Stores/TimerStore.swift`
- Modify: `HyperfocusTests/TimerStoreTests.swift`

- [ ] **Step 1: 실패 테스트 추가 — `TimerStoreTests.swift` 끝(마지막 `}` 앞)에 삽입**

```swift
    // MARK: - Focus blocking callbacks

    func test_start_firesOnBlockingStart() {
        let store = makeStore()
        var fired = false
        store.onBlockingStart = { fired = true }
        store.start()
        XCTAssertTrue(fired)
    }

    func test_start_doesNotFireOnBlockingStart_whenAlreadyRunning() {
        let store = makeStore()
        store.start()
        var callCount = 0
        store.onBlockingStart = { callCount += 1 }
        store.start()  // guard !isRunning이 막아야 함
        XCTAssertEqual(callCount, 0)
    }

    func test_pause_firesOnBlockingStop() {
        let store = makeStore()
        store.start()
        var fired = false
        store.onBlockingStop = { fired = true }
        store.pause()
        XCTAssertTrue(fired)
    }

    func test_resetSession_firesOnBlockingStop() {
        let store = makeStore()
        store.start()
        var fired = false
        store.onBlockingStop = { fired = true }
        store.resetSession()
        XCTAssertTrue(fired)
    }

    func test_pauseForSleep_firesOnBlockingStop() {
        let store = makeStore()
        store.start()
        var fired = false
        store.onBlockingStop = { fired = true }
        store.pauseForSleep()
        XCTAssertTrue(fired)
    }

    func test_pause_doesNotFireOnBlockingStop_whenAlreadyPaused() {
        let store = makeStore()
        store.start()
        store.pause()
        var callCount = 0
        store.onBlockingStop = { callCount += 1 }
        store.pause()  // guard isRunning이 막아야 함
        XCTAssertEqual(callCount, 0)
    }
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
cd /Users/jwchoi/Desktop/hyperfocus
xcodebuild test \
  -project Hyperfocus.xcodeproj \
  -scheme Hyperfocus \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:HyperfocusTests/TimerStoreTests/test_start_firesOnBlockingStart \
  2>&1 | grep -E "PASSED|FAILED|error:" | tail -10
```

Expected: `FAILED` (onBlockingStart 프로퍼티 없음)

- [ ] **Step 3: `TimerStore.swift` 수정 — 콜백 선언 추가**

`onDayClosed` / `onStateChanged` 선언 바로 아래에 추가:

```swift
    var onBlockingStart: (() -> Void)?
    var onBlockingStop: (() -> Void)?
```

- [ ] **Step 4: `start()` 끝에 `onBlockingStart?()` 호출 추가**

`start()` 함수의 `onStateChanged?()` 바로 앞에 삽입:

```swift
    func start() {
        guard !isRunning else { return }

        if activeSession == nil {
            activeSession = Session(startedAt: clock.now)
        }

        isRunning = true
        lastTickAt = clock.now
        startTicking()

        logger.info("Timer started")
        onBlockingStart?()   // ← 추가
        onStateChanged?()
    }
```

- [ ] **Step 5: `pauseInternal()` 끝에 `onBlockingStop?()` 호출 추가**

```swift
    private func pauseInternal(saveImmediately: Bool) {
        guard isRunning else { return }
        stopTicking()
        isRunning = false
        lastTickAt = nil

        logger.info("Timer paused (immediate=\(saveImmediately))")
        onBlockingStop?()    // ← 추가
        onStateChanged?()
    }
```

`pause()`, `pauseForSleep()` 모두 `pauseInternal`을 호출하므로 두 콜백이 자동으로 커버된다.

- [ ] **Step 6: `resetSession()` 끝에 `onBlockingStop?()` 호출 추가**

`resetSession()`의 `onStateChanged?()` 바로 앞에 삽입:

```swift
    func resetSession() {
        if isRunning {
            stopTicking()
            isRunning = false
        }

        commitActiveSessionIfNeeded()
        activeSession = nil

        logger.info("Session reset → idle")
        onBlockingStop?()    // ← 추가
        onStateChanged?()
    }
```

- [ ] **Step 7: `performRollover()` 에도 `onBlockingStop?()` 추가**

rollover는 `pauseInternal(saveImmediately: false)`을 이미 호출하므로 `pauseInternal` 안의 `onBlockingStop?()` 이 커버한다. 별도 추가 불필요.

- [ ] **Step 8: 테스트 통과 확인**

```bash
xcodebuild test \
  -project Hyperfocus.xcodeproj \
  -scheme Hyperfocus \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:HyperfocusTests/TimerStoreTests \
  2>&1 | grep -E "PASSED|FAILED|error:" | tail -10
```

Expected: 모든 TimerStoreTests `PASSED`

- [ ] **Step 9: 커밋**

```bash
git add Hyperfocus/Stores/TimerStore.swift \
        HyperfocusTests/TimerStoreTests.swift
git commit -m "feat: add onBlockingStart/onBlockingStop callbacks to TimerStore"
```

---

## Task 4: Info.plist — AppleScript 사용 권한 설명 추가

**Files:**
- Modify: `Hyperfocus/Info.plist`

Chrome 탭을 AppleScript로 제어하려면 macOS가 사용자에게 자동화 권한을 요청한다. 이 때 표시할 설명 문자열이 필요하다.

- [ ] **Step 1: `Info.plist`에 키 추가**

`LSUIElement` 항목 바로 뒤에 다음 두 줄을 삽입:

```xml
	<key>NSAppleEventsUsageDescription</key>
	<string>집중 모드 중 Chrome에서 차단된 사이트의 탭을 닫습니다.</string>
```

결과:

```xml
	<key>LSUIElement</key>
	<true/>
	<key>NSAppleEventsUsageDescription</key>
	<string>집중 모드 중 Chrome에서 차단된 사이트의 탭을 닫습니다.</string>
</dict>
```

- [ ] **Step 2: 빌드 오류 없음 확인**

```bash
cd /Users/jwchoi/Desktop/hyperfocus
xcodebuild build \
  -project Hyperfocus.xcodeproj \
  -scheme Hyperfocus \
  -destination 'platform=macOS,arch=arm64' \
  2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -5
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: 커밋**

```bash
git add Hyperfocus/Info.plist
git commit -m "feat: add NSAppleEventsUsageDescription for Chrome automation"
```

---

## Task 5: FocusBlocker 서비스

**Files:**
- Create: `Hyperfocus/Services/FocusBlocker.swift`

- [ ] **Step 1: `FocusBlocker.swift` 생성**

```swift
// Hyperfocus/Services/FocusBlocker.swift
import AppKit
import Combine
import os.log

private let logger = Logger(subsystem: "com.hyperfocus", category: "FocusBlocker")

final class FocusBlocker {
    private let focusStore: FocusStore
    private var launchObserver: NSObjectProtocol?
    private var chromePollCancellable: AnyCancellable?

    init(focusStore: FocusStore) {
        self.focusStore = focusStore
    }

    func activate() {
        terminateCurrentlyRunningBlockedApps()
        subscribeToAppLaunches()
        closeBlockedChromeTabs()
        startChromePoll()
        logger.info("FocusBlocker activated")
    }

    func deactivate() {
        if let obs = launchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            launchObserver = nil
        }
        chromePollCancellable?.cancel()
        chromePollCancellable = nil
        logger.info("FocusBlocker deactivated")
    }

    deinit { deactivate() }

    // MARK: - Private

    private func subscribeToAppLaunches() {
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.terminateIfBlocked(app)
        }
    }

    private func startChromePoll() {
        chromePollCancellable = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.closeBlockedChromeTabs() }
    }

    private func terminateCurrentlyRunningBlockedApps() {
        let blockedIDs = Set(focusStore.blockedApps.map { $0.bundleIdentifier })
        guard !blockedIDs.isEmpty else { return }
        NSWorkspace.shared.runningApplications
            .filter { app in
                guard let id = app.bundleIdentifier else { return false }
                return blockedIDs.contains(id)
            }
            .forEach {
                $0.forceTerminate()
                logger.info("Terminated running blocked app: \($0.bundleIdentifier ?? "?")")
            }
    }

    private func terminateIfBlocked(_ app: NSRunningApplication) {
        let blockedIDs = Set(focusStore.blockedApps.map { $0.bundleIdentifier })
        guard let id = app.bundleIdentifier, blockedIDs.contains(id) else { return }
        app.forceTerminate()
        logger.info("Terminated launched blocked app: \(id)")
    }

    private func closeBlockedChromeTabs() {
        let domains = focusStore.blockedSites.map { $0.domain }
        guard !domains.isEmpty else { return }
        // 도메인별 "or" 조건 동적 생성
        let conditions = domains.map { "u contains \"\($0)\"" }.joined(separator: " or ")
        let script = """
        if application "Google Chrome" is running then
            tell application "Google Chrome"
                repeat with w in (every window)
                    set tabList to (every tab of w)
                    repeat with t in tabList
                        set u to URL of t
                        if \(conditions) then
                            close t
                        end if
                    end repeat
                end repeat
            end tell
        end if
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }
}
```

- [ ] **Step 2: Xcode 프로젝트에 등록**

```bash
cd /Users/jwchoi/Desktop/hyperfocus
ruby -e "
require 'xcodeproj'
proj = Xcodeproj::Project.open('Hyperfocus.xcodeproj')
target = proj.targets.find { |t| t.name == 'Hyperfocus' }
group = proj.main_group['Hyperfocus']['Services']
ref = group.new_reference('FocusBlocker.swift')
target.source_build_phase.add_file_reference(ref)
proj.save
puts 'Added FocusBlocker.swift to Hyperfocus target'
"
```

- [ ] **Step 3: 빌드 확인**

```bash
xcodebuild build \
  -project Hyperfocus.xcodeproj \
  -scheme Hyperfocus \
  -destination 'platform=macOS,arch=arm64' \
  2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -5
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: 커밋**

```bash
git add Hyperfocus/Services/FocusBlocker.swift \
        Hyperfocus.xcodeproj/project.pbxproj
git commit -m "feat: add FocusBlocker service — app kill + Chrome tab polling"
```

---

## Task 6: HyperfocusApp 배선

**Files:**
- Modify: `Hyperfocus/HyperfocusApp.swift`

- [ ] **Step 1: `HyperfocusApp.swift` 전체 교체**

```swift
// Hyperfocus/HyperfocusApp.swift
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.hyperfocus", category: "App")

@main
struct HyperfocusApp: App {
    private let persistence = Persistence()
    private let timerStore: TimerStore
    private let statsStore: StatisticsStore
    private let focusStore: FocusStore
    private let sleepObserver: SleepObserver
    private let focusBlocker: FocusBlocker

    init() {
        let state = persistence.load()
        let stats = StatisticsStore(pastDays: state.pastDays)
        let timer = TimerStore(
            currentDay: state.currentDay,
            activeSession: state.activeSession
        )
        let focus = FocusStore(blocklist: state.focusBlocklist)
        let blocker = FocusBlocker(focusStore: focus)

        self.statsStore = stats
        self.timerStore = timer
        self.focusStore = focus
        self.focusBlocker = blocker

        // Catch up on any 6am rollovers that happened while app was closed
        timer.checkAndPerformRollover()

        // Wire day-closed callback
        timer.onDayClosed = { [weak stats] day in
            stats?.appendClosedDay(day)
        }

        // Wire blocking callbacks
        timer.onBlockingStart = { [weak blocker] in blocker?.activate() }
        timer.onBlockingStop = { [weak blocker] in blocker?.deactivate() }

        // Wire state-changed callbacks to trigger debounced persistence
        let p = persistence
        let saveState = { [weak timer, weak stats, weak focus] in
            guard let t = timer, let s = stats, let f = focus else { return }
            p.requestSave(PersistedState(
                currentDay: t.currentDay,
                pastDays: s.pastDays,
                activeSession: t.activeSession,
                focusBlocklist: FocusBlocklist(
                    blockedApps: f.blockedApps,
                    blockedSites: f.blockedSites
                )
            ))
        }
        timer.onStateChanged = saveState
        stats.onStateChanged = saveState
        focus.onStateChanged = saveState

        // Auto-pause and immediate flush before system sleep; rollover check on wake
        self.sleepObserver = SleepObserver(
            onSleep: { [weak timer, weak stats, weak focus] in
                guard let t = timer else { return }
                t.pauseForSleep()
                guard let s = stats, let f = focus else { return }
                p.saveNow(PersistedState(
                    currentDay: t.currentDay,
                    pastDays: s.pastDays,
                    activeSession: t.activeSession,
                    focusBlocklist: FocusBlocklist(
                        blockedApps: f.blockedApps,
                        blockedSites: f.blockedSites
                    )
                ))
                logger.info("State flushed before sleep")
            },
            onWake: { [weak timer] in
                timer?.checkAndPerformRollover()
                logger.info("Rollover check on wake")
            }
        )

        // Final flush on quit — deactivate blocker first
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak timer, weak stats, weak focus, weak blocker] _ in
            blocker?.deactivate()
            guard let t = timer, let s = stats, let f = focus else { return }
            p.saveNow(PersistedState(
                currentDay: t.currentDay,
                pastDays: s.pastDays,
                activeSession: t.activeSession,
                focusBlocklist: FocusBlocklist(
                    blockedApps: f.blockedApps,
                    blockedSites: f.blockedSites
                )
            ))
            logger.info("State flushed on termination")
        }

        logger.info("App initialized")
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverRoot()
                .environment(timerStore)
                .environment(statsStore)
                .environment(focusStore)
        } label: {
            MenuBarLabel()
                .environment(timerStore)
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 2: 빌드 확인**

```bash
cd /Users/jwchoi/Desktop/hyperfocus
xcodebuild build \
  -project Hyperfocus.xcodeproj \
  -scheme Hyperfocus \
  -destination 'platform=macOS,arch=arm64' \
  2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -5
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: 전체 테스트 통과 확인**

```bash
xcodebuild test \
  -project Hyperfocus.xcodeproj \
  -scheme Hyperfocus \
  -destination 'platform=macOS,arch=arm64' \
  2>&1 | grep -E "Test Suite.*passed|FAILED|error:" | tail -10
```

Expected: `Test Suite 'All tests' passed`

- [ ] **Step 4: 커밋**

```bash
git add Hyperfocus/HyperfocusApp.swift
git commit -m "feat: wire FocusStore and FocusBlocker into HyperfocusApp"
```

---

## Task 7: Focus UI — FocusScreen + AppPickerView

**Files:**
- Create: `Hyperfocus/Views/Focus/FocusScreen.swift`
- Create: `Hyperfocus/Views/Focus/AppPickerView.swift`

- [ ] **Step 1: `Views/Focus/` 디렉토리 생성 및 `FocusScreen.swift` 작성**

```swift
// Hyperfocus/Views/Focus/FocusScreen.swift
import SwiftUI

struct FocusScreen: View {
    @Environment(TimerStore.self) private var timerStore
    @Environment(FocusStore.self) private var focusStore
    let onBack: () -> Void

    @State private var showingAppPicker = false
    @State private var showingSiteInput = false
    @State private var newSiteDomain = ""

    private var isBlocking: Bool { timerStore.isRunning }

    var body: some View {
        VStack(spacing: 0) {
            navigationBar

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    statusBadge
                    blockedAppsSection
                    blockedSitesSection
                }
                .padding()
            }
        }
    }

    // MARK: - Navigation bar (Stats 화면과 동일한 패턴)

    private var navigationBar: some View {
        ZStack {
            Text("Focus")
                .font(.headline)
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Timer")
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Status badge

    private var statusBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isBlocking ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
            Text(isBlocking ? "집중 중 — 차단 활성" : "세션 시작 시 자동 활성")
                .font(.caption)
                .foregroundStyle(isBlocking ? Color.green : Color.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Blocked apps

    private var blockedAppsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("차단 앱")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    showingAppPicker = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .disabled(isBlocking)
                .popover(isPresented: $showingAppPicker, arrowEdge: .trailing) {
                    AppPickerView(isPresented: $showingAppPicker)
                        .environment(focusStore)
                        .frame(width: 220)
                }
            }

            if focusStore.blockedApps.isEmpty {
                Text("추가된 앱 없음")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 0) {
                    ForEach(focusStore.blockedApps) { app in
                        HStack {
                            Text(app.displayName)
                                .font(.system(size: 13))
                            Spacer()
                            Button {
                                focusStore.removeApp(id: app.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(isBlocking)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)

                        if app.id != focusStore.blockedApps.last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    // MARK: - Blocked sites

    private var blockedSitesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("차단 사이트 (Chrome)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    showingSiteInput = true
                    newSiteDomain = ""
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .disabled(isBlocking)
            }

            if showingSiteInput {
                HStack {
                    TextField("예: linkedin.com", text: $newSiteDomain)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                        .onSubmit { commitNewSite() }
                    Button("추가") { commitNewSite() }
                        .buttonStyle(.bordered)
                        .font(.system(size: 12))
                        .disabled(newSiteDomain.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            if focusStore.blockedSites.isEmpty && !showingSiteInput {
                Text("추가된 사이트 없음")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if !focusStore.blockedSites.isEmpty {
                VStack(spacing: 0) {
                    ForEach(focusStore.blockedSites) { site in
                        HStack {
                            Text(site.domain)
                                .font(.system(size: 13))
                            Spacer()
                            Button {
                                focusStore.removeSite(id: site.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(isBlocking)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)

                        if site.id != focusStore.blockedSites.last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private func commitNewSite() {
        let domain = newSiteDomain.trimmingCharacters(in: .whitespaces)
        guard !domain.isEmpty else { return }
        focusStore.addSite(BlockedSite(id: UUID(), domain: domain))
        showingSiteInput = false
        newSiteDomain = ""
    }
}
```

- [ ] **Step 2: `AppPickerView.swift` 작성**

```swift
// Hyperfocus/Views/Focus/AppPickerView.swift
import SwiftUI
import AppKit

struct AppPickerView: View {
    @Environment(FocusStore.self) private var focusStore
    @Binding var isPresented: Bool

    private var availableApps: [NSRunningApplication] {
        let blockedIDs = Set(focusStore.blockedApps.map { $0.bundleIdentifier })
        return NSWorkspace.shared.runningApplications
            .filter { app in
                app.activationPolicy == .regular &&
                app.localizedName != nil &&
                !blockedIDs.contains(app.bundleIdentifier ?? "")
            }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("실행 중인 앱")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

            Divider()

            if availableApps.isEmpty {
                Text("추가할 수 있는 앱이 없습니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
            } else {
                ForEach(availableApps, id: \.bundleIdentifier) { app in
                    appRow(app)
                    if app.bundleIdentifier != availableApps.last?.bundleIdentifier {
                        Divider()
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func appRow(_ app: NSRunningApplication) -> some View {
        Button {
            focusStore.addApp(BlockedApp(
                id: UUID(),
                bundleIdentifier: app.bundleIdentifier ?? "",
                displayName: app.localizedName ?? ""
            ))
            isPresented = false
        } label: {
            HStack(spacing: 8) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                Text(app.localizedName ?? "")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 3: Xcode 프로젝트에 등록 (Views/Focus 그룹 신규 생성)**

```bash
cd /Users/jwchoi/Desktop/hyperfocus
ruby -e "
require 'xcodeproj'
proj = Xcodeproj::Project.open('Hyperfocus.xcodeproj')
target = proj.targets.find { |t| t.name == 'Hyperfocus' }
views_group = proj.main_group['Hyperfocus']['Views']
focus_group = views_group.new_group('Focus', 'Focus')
['FocusScreen.swift', 'AppPickerView.swift'].each do |fname|
  ref = focus_group.new_reference(fname)
  target.source_build_phase.add_file_reference(ref)
end
proj.save
puts 'Added Focus group with FocusScreen.swift and AppPickerView.swift'
"
```

- [ ] **Step 4: 빌드 확인**

```bash
xcodebuild build \
  -project Hyperfocus.xcodeproj \
  -scheme Hyperfocus \
  -destination 'platform=macOS,arch=arm64' \
  2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -5
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: 커밋**

```bash
git add Hyperfocus/Views/Focus/ \
        Hyperfocus.xcodeproj/project.pbxproj
git commit -m "feat: add FocusScreen and AppPickerView UI"
```

---

## Task 8: 네비게이션 통합 — PopoverRoot / TimerScreen / TimerControls

**Files:**
- Modify: `Hyperfocus/Views/PopoverRoot.swift`
- Modify: `Hyperfocus/Views/Timer/TimerScreen.swift`
- Modify: `Hyperfocus/Views/Timer/TimerControls.swift`

- [ ] **Step 1: `PopoverRoot.swift` 수정 — `.focus` 케이스 추가**

```swift
// Hyperfocus/Views/PopoverRoot.swift
import SwiftUI

enum PopoverScreen {
    case timer
    case stats
    case dayDetail(Day)
    case focus
}

struct PopoverRoot: View {
    @Environment(TimerStore.self) private var timerStore
    @Environment(StatisticsStore.self) private var statsStore
    @Environment(FocusStore.self) private var focusStore
    @State private var screen: PopoverScreen = .timer

    var body: some View {
        switch screen {
        case .timer:
            TimerScreen(
                onShowStats: { screen = .stats },
                onShowFocus: { screen = .focus }
            )
            .frame(width: 300)
        case .stats:
            StatsScreen(
                onBack: { screen = .timer },
                onSelectDay: { day in screen = .dayDetail(day) }
            )
            .frame(width: 420, height: 820)
        case .dayDetail(let day):
            DayDetailView(day: day, onBack: { screen = .stats })
                .frame(width: 420, height: 820)
        case .focus:
            FocusScreen(onBack: { screen = .timer })
                .frame(width: 300)
        }
    }
}
```

- [ ] **Step 2: `TimerScreen.swift` 수정 — `onShowFocus` 파라미터 추가**

```swift
// Hyperfocus/Views/Timer/TimerScreen.swift
import SwiftUI
import AppKit

struct TimerScreen: View {
    @Environment(TimerStore.self) private var timerStore
    @Environment(\.dismiss) private var dismiss
    let onShowStats: () -> Void
    let onShowFocus: () -> Void   // ← 추가

    @State private var spaceKeyMonitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TitleField()

            TimeDisplayView(
                currentDuration: timerStore.currentSessionDuration,
                totalDuration: timerStore.totalDuration
            )

            TimerControls(onShowStats: onShowStats, onShowFocus: onShowFocus)  // ← onShowFocus 전달
        }
        .padding()
        .onAppear { setupSpaceKeyMonitor() }
        .onDisappear { teardownSpaceKeyMonitor() }
    }

    // MARK: - Space key shortcut (SPEC §3.2)
    // NSEvent monitor: SleepObserver와 동일 패턴으로 AppKit 이벤트를 직접 가로챔.
    // SwiftUI .onKeyPress는 포커스 체인에 의존해 idle/running 전환 시 신뢰성이 낮아 사용하지 않음.

    private func setupSpaceKeyMonitor() {
        guard spaceKeyMonitor == nil else { return }
        let store = timerStore
        let dismissAction = dismiss
        spaceKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == 49,
                  event.modifierFlags.intersection([.shift, .control, .option, .command]).isEmpty,
                  !(NSApp.keyWindow?.firstResponder is NSTextView)
            else { return event }

            if store.isRunning {
                store.pause()
                return nil
            } else if store.activeSession != nil {
                store.start()
                dismissAction()
                return nil
            }
            return event
        }
    }

    private func teardownSpaceKeyMonitor() {
        if let monitor = spaceKeyMonitor {
            NSEvent.removeMonitor(monitor)
            spaceKeyMonitor = nil
        }
    }
}
```

- [ ] **Step 3: `TimerControls.swift` 수정 — Focus 버튼 추가**

```swift
// Hyperfocus/Views/Timer/TimerControls.swift
import SwiftUI

struct TimerControls: View {
    @Environment(TimerStore.self) private var timerStore
    let onShowStats: () -> Void
    let onShowFocus: () -> Void   // ← 추가

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.bottom, 10)

            primaryButtons
                .padding(.bottom, 10)

            Divider()
                .padding(.bottom, 10)

            secondaryButtons
        }
    }

    @ViewBuilder
    private var primaryButtons: some View {
        if timerStore.isRunning {
            HStack(spacing: 10) {
                Button("Pause") { timerStore.pause() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                Button("End") { timerStore.resetSession() }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .frame(maxWidth: .infinity)
            }
        } else if timerStore.activeSession != nil {
            HStack(spacing: 10) {
                Button("Resume") { timerStore.start() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                Button("End") { timerStore.resetSession() }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .frame(maxWidth: .infinity)
            }
        } else {
            Button("Start") { timerStore.start() }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
    }

    private var secondaryButtons: some View {
        HStack(spacing: 10) {
            Button("Stats") { onShowStats() }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            Button("Focus") { onShowFocus() }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
        }
    }
}
```

- [ ] **Step 4: 빌드 확인**

```bash
cd /Users/jwchoi/Desktop/hyperfocus
xcodebuild build \
  -project Hyperfocus.xcodeproj \
  -scheme Hyperfocus \
  -destination 'platform=macOS,arch=arm64' \
  2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -5
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: 전체 테스트 통과 확인**

```bash
xcodebuild test \
  -project Hyperfocus.xcodeproj \
  -scheme Hyperfocus \
  -destination 'platform=macOS,arch=arm64' \
  2>&1 | grep -E "Test Suite.*passed|FAILED|error:" | tail -10
```

Expected: `Test Suite 'All tests' passed`

- [ ] **Step 6: 최종 커밋**

```bash
git add Hyperfocus/Views/PopoverRoot.swift \
        Hyperfocus/Views/Timer/TimerScreen.swift \
        Hyperfocus/Views/Timer/TimerControls.swift
git commit -m "feat: integrate Focus screen into navigation (PopoverRoot, TimerScreen, TimerControls)"
```

---

## 완료 체크리스트

- [ ] 모든 테스트 통과 (`xcodebuild test` 녹색)
- [ ] 빌드 경고 0개
- [ ] 타이머 Start → 차단 앱 즉시 종료 확인 (Console.app에서 `FocusBlocker` 카테고리 로그 확인)
- [ ] 타이머 Pause → 차단 해제, Resume → 재차단 확인
- [ ] Focus 탭: 앱 피커에서 실행 중인 앱 목록 표시 및 추가 확인
- [ ] Focus 탭: 사이트 도메인 입력 후 Return으로 저장 확인
- [ ] 앱 재시작 후 차단 목록 유지 확인
