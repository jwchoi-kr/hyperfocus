# Focus Mode — 설계 문서

**날짜:** 2026-05-29  
**상태:** 승인됨

---

## 1. 개요

타이머가 실제로 동작 중인(running) 동안만 방해 앱을 자동으로 종료하고, Chrome에서 특정 사이트를 차단하는 "Focus Mode" 기능을 Hyperfocus에 추가한다. Pause 중이거나 idle 상태에서는 차단하지 않는다. 설정은 Popover의 새 Focus 탭에서 관리하며, 한 번 설정하면 앱 재시작 후에도 유지된다.

---

## 2. 동작 정의

### 2.1 활성화 / 비활성화 조건

| 이벤트 | 차단 상태 |
|--------|-----------|
| `Start` 버튼 (또는 Return 키로 세션 시작) | 즉시 활성화 |
| `Pause` 버튼 | 비활성화 |
| `Resume` 버튼 | 즉시 활성화 |
| `End` 버튼 | 비활성화 |
| 새벽 6시 자동 마감 (rollover) | 비활성화 |
| 슬립 자동 일시정지 | 비활성화 |

별도 토글 없음 — 타이머가 running 상태일 때만 차단 활성. idle(세션 없음)·paused(일시정지) 상태에서는 차단하지 않는다.

### 2.2 앱 차단

- `NSWorkspace.didLaunchApplicationNotification`을 구독하여 앱이 실행되는 순간 즉시 감지.
- 차단 목록의 bundle identifier와 일치하면 즉시 강제 종료(`NSRunningApplication.forceTerminate()`).
- 이미 실행 중인 앱은 `FocusBlocker.activate()` 호출 시점에 목록을 순회하여 종료.
- 반응 지연: 0초 (알림 기반).

### 2.3 사이트 차단 (Chrome 전용)

- 2초마다 `NSAppleScript`로 Chrome의 모든 탭 URL을 조회.
- 차단 도메인이 URL에 포함되어 있으면 해당 탭을 닫음.
- 반응 지연: 최대 2초.
- Chrome 자동화 권한이 없으면 최초 실행 시 macOS가 권한 요청 다이얼로그를 표시함 — 앱이 별도 UI를 띄우지 않아도 자동으로 처리됨.
- Chrome이 실행 중이지 않으면 폴링 타이머는 아무 작업도 하지 않음.

---

## 3. 새 컴포넌트

### 3.1 `FocusStore` (`Stores/FocusStore.swift`)

- `@Observable` 클래스.
- 보유 상태: `blockedApps: [BlockedApp]`, `blockedSites: [BlockedSite]`
- 액션: `addApp(_:)`, `removeApp(id:)`, `addSite(_:)`, `removeSite(id:)`
- 변경 시마다 `onStateChanged?()` 콜백 호출 → `Persistence.requestSave()`

```swift
struct BlockedApp: Codable, Identifiable {
    var id: UUID
    var bundleIdentifier: String  // "com.kakao.KakaoTalk"
    var displayName: String       // "카카오톡"
}

struct BlockedSite: Codable, Identifiable {
    var id: UUID
    var domain: String            // "linkedin.com"
}
```

### 3.2 `FocusBlocker` (`Services/FocusBlocker.swift`)

- 생성자에 `FocusStore` 참조를 받음.
- `activate()`: NSWorkspace 알림 구독 시작 + 폴링 타이머 시작 + 현재 실행 앱 즉시 종료 + Chrome 탭 즉시 1회 확인.
- `deactivate()`: 알림 구독 해제 + 폴링 타이머 정지.
- Chrome AppleScript:
  ```applescript
  tell application "Google Chrome"
    repeat with w in windows
      repeat with t in tabs of w
        if URL of t contains "linkedin.com" then close t
      end repeat
    end repeat
  end tell
  ```

### 3.3 `FocusScreen` (`Views/Focus/FocusScreen.swift`)

- Focus 탭의 루트 뷰.
- 상단: 현재 차단 상태 배지 (활성 = 초록, 비활성 = 회색).
- "차단 앱" 섹션:
  - 앱 목록 (아이콘 + 이름 + × 버튼).
  - `+` 버튼 → `AppPickerView` 표시.
- "차단 사이트" 섹션:
  - 사이트 목록 (도메인 + × 버튼).
  - `+` 버튼 → 인라인 텍스트 필드(도메인 입력, Return으로 저장).
- 차단 활성 중에는 편집(추가/삭제) 비활성화.

### 3.4 `AppPickerView` (`Views/Focus/AppPickerView.swift`)

- `NSWorkspace.shared.runningApplications`에서 앱 목록 로드. `activationPolicy == .regular`인 앱만 표시 (Dock에 나타나는 일반 앱).
- 이미 차단 목록에 있는 앱은 제외.
- 각 행: 실제 앱 아이콘(`NSRunningApplication.icon`) + 앱 이름(`localizedName`).
- 탭 즉시 추가 + 저장.

---

## 4. 기존 파일 변경

### 4.1 `TimerStore`

`onBlockingStart: (() -> Void)?`, `onBlockingStop: (() -> Void)?` 콜백 추가.

- `start()` 끝에 `onBlockingStart?()` 호출.
- `pause()`, `resetSession()`, `pauseForSleep()`, rollover 마감 시 `onBlockingStop?()` 호출.

### 4.2 `HyperfocusApp`

- `FocusStore`, `FocusBlocker` 생성.
- `timerStore.onBlockingStart = { focusBlocker.activate() }`
- `timerStore.onBlockingStop = { focusBlocker.deactivate() }`
- `FocusStore`를 환경 객체로 주입.
- 앱 종료 시 `focusBlocker.deactivate()` 호출.

### 4.3 `PopoverRoot`

탭 3개로 확장: Timer · Stats · Focus.  
Popover 크기: Focus 탭은 타이머 탭과 동일한 300pt 너비 사용.

### 4.4 `PersistedState`

`focusBlocklist: FocusBlocklist` 필드 추가.

```swift
struct FocusBlocklist: Codable {
    var blockedApps: [BlockedApp]
    var blockedSites: [BlockedSite]
}
```

---

## 5. 엣지 케이스

| 상황 | 동작 |
|------|------|
| 차단 앱이 이미 실행 중인 채로 세션 시작 | `activate()` 시점에 즉시 종료 |
| Chrome 자동화 권한 없음 | macOS가 최초 실행 시 권한 다이얼로그 자동 표시. 거부 시 사이트 차단만 작동 안 함, 앱 차단은 정상 동작 |
| Chrome 미실행 중 | 폴링 타이머가 실행되지만 AppleScript가 조용히 실패(noop). 에러 없음 |
| 차단 목록이 비어 있는 상태로 세션 시작 | `activate()` 호출되지만 아무것도 차단하지 않음. 정상 동작 |
| 세션 중 차단 목록 편집 시도 | UI 비활성화(편집 불가). 세션 종료 후 편집 가능 |
| 슬립 → wake 시 세션이 paused 상태 | paused이므로 차단 비활성 상태. Resume 시 다시 활성화 |
| 앱 종료 시 차단 활성 중 | `willTerminateNotification`에서 `deactivate()` 호출 |

---

## 6. Out of Scope (이번 버전)

- Safari, Firefox 등 Chrome 외 브라우저 차단.
- `/etc/hosts` 기반 시스템 수준 사이트 차단.
- 차단 프로필 여러 개 (목록은 하나).
- 차단 시 사용자에게 알림(토스트 등) 표시.
- 시간대별 스케줄 차단.
