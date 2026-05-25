# Hyperfocus 아키텍처

이 문서는 [SPEC.md](./SPEC.md)에 정의된 동작을 구현하기 위해 사용할 기술 스택과
프로젝트의 코드 구조를 정의한다. 구현 디테일(함수 시그니처 등)은 코드에 맡기고,
이 문서는 "어떤 기술로, 어떤 레이어 구분으로 만들지"까지만 다룬다.

---

## 1. 기술 스택

### 1.1 언어 / UI 프레임워크
- **Swift** (최신 안정 버전)
- **SwiftUI** — UI 전반
- **AppKit** — SwiftUI로 직접 다루기 어려운 macOS 시스템 이벤트(슬립 알림 등) 처리에만 보조적으로 사용

### 1.2 메뉴바 통합
- **`MenuBarExtra`** (SwiftUI, macOS 13+) — 메뉴바 라벨 + Popover 컨텐츠를 모두 SwiftUI로 선언
- Popover처럼 동작시키기 위해 `.menuBarExtraStyle(.window)`를 사용
- 메인 윈도우는 생성하지 않음. `Info.plist`에서 `LSUIElement = YES`로 Dock/앱 스위처 미노출

### 1.3 상태 관리
- **Observation 프레임워크의 `@Observable` 매크로** (Swift 5.9+, macOS 14+)
  - 두 개의 store(`TimerStore`, `StatisticsStore`)를 환경 객체로 주입
- 타이머 tick은 `Timer.publish(every: 1.0, on: .main, in: .common)` 기반.
  실제 경과 시간은 `Date.now - lastTickAt` 차이로 계산하여 시스템 부하 시 드리프트를 보정

### 1.4 영속화
- 별도 DB 없이 **단일 JSON 파일** (`Codable` 직렬화)
- 저장 위치: `~/Library/Application Support/Hyperfocus/state.json`
- 데이터 규모(주기당 수십~수백 세션, 무기한 누적)에서도 JSON 한 파일로 충분
- 쓰기 시점: 상태 변경 이벤트마다 즉시 flush, 이름 입력은 짧은 디바운스(약 0.5초)
- 종료 직전에도 한 번 flush (`NSApplication.willTerminateNotification`)

### 1.5 시스템 이벤트
- **`NSWorkspace.shared.notificationCenter`**
  - `.willSleepNotification` 구독 → 자동 일시정지
  - `.didWakeNotification` 구독 → 자동 재개 없음(SPEC §8.2), 새벽 6시 경계 초과 여부 확인 후 필요 시 자동 마감 수행 (SPEC §5.5)
- 앱 실행 시 및 슬립에서 깨어날 때: 마지막 저장 하루 시작 시각과 현재 시각을 비교하여 자동 마감 여부 결정
- 새벽 6시 타이머: 앱 실행 중에는 다음 새벽 6시 시각을 계산하여 `Timer`로 자동 마감 스케줄링. 마감 후 그 다음 6시로 재스케줄
- **`NSEvent.addLocalMonitorForEvents`** — Popover 컨테이너 레벨의 Space 키 처리 (SPEC §3.2). SwiftUI `.onKeyPress`는 포커스 체인 의존성으로 idle/running 전환 시 신뢰성이 낮아 AppKit 이벤트 모니터를 사용함. TitleField의 Return 키는 SwiftUI `.onSubmit` 사용 (SPEC §4.1)

### 1.6 외부 의존성
- **없음.** 표준 Apple 프레임워크(Swift, SwiftUI, AppKit, Foundation, Combine, Observation)만 사용
- 패키지 매니저는 Swift Package Manager를 기본으로 두지만, 현 시점에는 사용처 없음

### 1.7 빌드 / 배포
- **Xcode 프로젝트** (`.xcodeproj`)로 관리. 빌드 시스템은 `xcodebuild`
- 배포 타깃: **macOS 14.0+** (Observation 프레임워크 + 최신 `MenuBarExtra` 동작 보장)
- 코드 사이닝은 개인 사용 단계에서는 "Sign to Run Locally"로 충분

### 1.8 테스트
- **XCTest** 단위 테스트
- 우선 대상: 타이머 누적 계산, 세션 합산 로직, 일평균 계산, 영속화 round-trip
- UI 테스트는 이번 범위에서 제외

---

## 2. 아키텍처 원칙

### 2.1 단방향 데이터 흐름
- 사용자 액션 → Store의 메서드 호출 → Store가 상태 변경 → SwiftUI 뷰 자동 갱신 → Persistence가 그 변경을 디스크에 반영
- 뷰는 상태를 직접 변형하지 않고 항상 Store 메서드를 통한다

### 2.2 단일 진실의 원천
- "전체 시간"은 별도로 저장하지 않는다. 항상 `현재 주기의 모든 세션 누적 시간 + 진행 중 세션의 누적 시간`으로 파생
- 이 원칙 덕에 세션 리셋, 전체 리셋 동작이 단순해진다 (계산된 값이 자동으로 맞아떨어짐)

### 2.3 시간 계산은 벽시계 기준
- 매초 단순 카운트가 아니라, 마지막 tick 시각(`lastTickAt`)과 현재 시각의 차이를 누적
- 시스템이 잠시 멈췄다 깨어나는 경우(슬립 외 일반 부하) 시간 손실을 막음
- 슬립 시점에는 의도적으로 일시정지하므로 슬립 구간은 자연히 가산되지 않음

### 2.4 비-목표 영역
- 동기화/네트워크 없음 → 충돌 해결 로직 없음
- 마이그레이션은 첫 릴리스에서는 고려 안 함. JSON 스키마에 `schemaVersion` 필드만 미리 박아둠

---

## 3. 프로젝트 구조

Xcode 프로젝트 루트: `/Users/jwchoi/Desktop/hyperfocus/Hyperfocus/`

```
hyperfocus/
├── docs/
│   ├── SPEC.md
│   └── architecture.md
├── Hyperfocus.xcodeproj/
└── Hyperfocus/
    ├── HyperfocusApp.swift              # @main, MenuBarExtra 선언, Store 주입
    ├── Info.plist                     # LSUIElement = YES
    ├── Assets.xcassets/               # 메뉴바 아이콘 (SF Symbol 미사용 시)
    │
    ├── Models/
    │   ├── Session.swift              # 세션 (id, name, duration, startedAt)
    │   ├── Cycle.swift                # 주기 (id, startedAt, endedAt?, sessions[])
    │   └── PersistedState.swift       # 디스크 저장용 루트 구조 + schemaVersion
    │
    ├── Stores/
    │   ├── TimerStore.swift           # 진행 중인 세션 + 현재 하루 상태, 타이머 동작, 6시 자동 마감
    │   └── StatisticsStore.swift      # 마감된 과거 하루 목록 + 통계 계산
    │
    ├── Services/
    │   ├── Persistence.swift          # JSON 파일 load/save, debounced flush
    │   ├── SleepObserver.swift        # NSWorkspace sleep/wake 알림 구독, 콜백 전달
    │   └── Clock.swift                # Date.now 추상화 (테스트 시 교체용)
    │
    ├── Views/
    │   ├── MenuBarLabel.swift         # 메뉴바 라벨 (아이콘 / 시간 텍스트 토글)
    │   ├── PopoverRoot.swift          # 타이머 ↔ 통계 화면 스위처
    │   ├── Timer/
    │   │   ├── TimerScreen.swift      # 타이머 화면 컨테이너
    │   │   ├── TimeDisplayView.swift  # Current/Today HH:MM:SS 표시 컴포넌트
    │   │   ├── TitleField.swift       # Title 입력/표시 필드 (두 모드)
    │   │   └── TimerControls.swift    # Start/Pause/Resume/Reset/End/Stats 버튼
    │   └── Stats/
    │       ├── StatsScreen.swift      # 통계 화면 컨테이너 (요약 + 목록)
    │       ├── AverageSummaryView.swift
    │       ├── CurrentCycleCardView.swift
    │       ├── PastCycleRowView.swift
    │       └── CycleDetailView.swift  # 과거 주기 상세 (이름별 합산)
    │
    └── Utilities/
        ├── TimeFormatting.swift       # "HH:MM:SS", "5h 42m" 포매터
        └── SessionAggregation.swift   # 같은 이름 합산 계산 헬퍼

HyperfocusTests/
├── TimerStoreTests.swift
├── SessionAggregationTests.swift
├── PersistenceTests.swift
└── AverageCalculationTests.swift
```

### 3.1 레이어 책임 요약

| 레이어 | 폴더 | 책임 | 외부에 노출하는 것 |
| --- | --- | --- | --- |
| Models | `Models/` | 도메인 데이터의 형태 정의. 로직 없음. `Codable` | 값 타입(struct) |
| Stores | `Stores/` | 도메인 로직 + 상태 보유. `@Observable` | 액션 메서드, 파생 프로퍼티 |
| Services | `Services/` | 외부 세계와의 경계 (디스크, 시스템 알림, 시계) | 프로토콜 + 기본 구현 |
| Views | `Views/` | 화면 렌더링. 상태를 읽고 Store 메서드만 호출 | SwiftUI View |
| Utilities | `Utilities/` | 순수 함수성 헬퍼 (포매팅, 합산) | 함수/extension |

### 3.2 의존 방향
- `Views` → `Stores` → `Services`, `Models`
- `Stores`는 `Services`를 **프로토콜로** 의존 (테스트에서 교체 가능)
- `Views`는 `Services`를 직접 모르고, 오직 `Stores`만 본다
- `Models`, `Utilities`는 다른 어떤 레이어에도 의존하지 않는 순수 코드

---

## 4. 주요 컴포넌트 책임 상세

### 4.1 `HyperfocusApp`
- `@main`. `MenuBarExtra`를 선언하고 그 안에 `PopoverRoot`를 둔다
- 앱 시작 시 `Persistence`로부터 상태를 로드하여 `TimerStore`/`StatisticsStore`에 주입
- 상태 로드 직후 `TimerStore.checkAndPerformRollover()`를 호출 — 앱 종료 중 새벽 6시를 넘긴 경우 처리 (SPEC §5.5)
- 종료 시점에 마지막 flush를 호출
- `SleepObserver`를 띄워 `TimerStore.pause()`(onSleep)와 `TimerStore.checkAndPerformRollover()`(onWake)에 연결

### 4.2 `TimerStore`
- 보유 상태: `currentDay: Day`, `activeSession: Session?`, `isRunning: Bool`, `lastTickAt: Date?`
- 타이머 상태는 3가지:
  - **idle**: `activeSession == nil, isRunning == false` → `Start` 버튼
  - **running**: `activeSession != nil, isRunning == true` → `Pause` + `Reset` 버튼
  - **paused**: `activeSession != nil, isRunning == false` → `Resume` + `Reset` 버튼
- 액션: `start()`, `pause()`, `pauseForSleep()`, `resetSession()`, `endDay()`, `updateActiveSessionName(_:)`
  - `start()`: idle이면 새 세션 생성 후 시작, paused이면 기존 세션 이어서 시작
  - `resetSession()`: 현재 세션 종료(duration > 0이면 저장), 타이머 정지, `activeSession = nil` (idle 복귀)
  - `endDay()`: 현재 하루 마감 + `onDayClosed` 콜백으로 `StatisticsStore`에 전달(빈 하루 제외) + 새 하루 시작. End 버튼에서 호출
  - `checkAndPerformRollover()`: 현재 시각이 마지막 저장 하루의 새벽 6시 경계를 넘었으면 `endDay()` 호출. 앱 실행·wake 시점에 호출 (미구현 — 향후 과제)
- 6시 타이머: `checkAndPerformRollover()` 구현 후 다음 새벽 6시 시각으로 `Timer`를 재스케줄 (미구현)
- 파생: `currentSessionDuration`, `totalDuration`
- 타이머 tick에서 `activeSession.duration += clock.now - lastTickAt` 패턴으로 누적
- 상태가 바뀔 때마다 `onStateChanged?()` 콜백 호출 → `HyperfocusApp`이 `Persistence.requestSave()` 실행

### 4.3 `StatisticsStore`
- 보유 상태: `pastDays: [Day]` (시간 역순 정렬 가정)
- `TimerStore.endDay()` 호출 시점에 `onDayClosed` 콜백으로 마감 하루를 받음 (빈 하루는 push하지 않음)
- 파생: `recentAverage(count: Int)` — SPEC §7.3 일평균 계산
- 합산 뷰 데이터(`aggregatedSessions(of: Day) -> [AggregatedSession]`)는 `SessionAggregation` 유틸을 호출
- 진행 중 세션 포함 버전: `aggregatedSessionsIncluding(day:active:)` — 오늘 카드에서 사용

### 4.4 `Persistence`
- 단일 JSON 파일 입출력. 첫 실행 시 빈 상태 반환
- `requestSave()`는 디바운스: 짧은 시간 내 다회 호출 시 마지막 한 번만 디스크 기록
- 디스크 쓰기는 백그라운드 큐, 실패는 콘솔 로깅 (사용자 알림 없음)
- 동시성 위험을 최소화하기 위해 메인 액터에서 직렬화된 데이터를 받아 백그라운드에서 쓴다

### 4.5 `SleepObserver`
- 생성자에 `onSleep: () -> Void`, `onWake: () -> Void` 클로저를 받아 보관
- `.willSleepNotification` → `onSleep` 호출 (자동 일시정지)
- `.didWakeNotification` → `onWake` 호출 (롤오버 체크 트리거. 자동 재개 아님)
- 단순 wrapper. 테스트에선 mock 사용

### 4.6 `Clock`
- `protocol ClockProtocol { var now: Date { get } }`. 기본 구현은 `struct SystemClock`으로 `Date()` 반환
- `TimerStore` 테스트에서 시간을 임의로 흘리기 위해 도입 (`MockClock`으로 교체)

### 4.7 View 레이어
- 모든 뷰는 `@Environment`로 Store를 주입받는다 (private state 최소화)
- `MenuBarLabel`은 `currentSessionDuration`만 본다. **항상 `HH:MM:SS` 텍스트로 표시** (idle이면 `00:00:00`). 아이콘 전환 없음 (SPEC §3.1). 구현은 `NSImage`에 텍스트를 그려 반환하는 방식(`isTemplate = true`로 라이트/다크 자동 대응)
- 시간 텍스트는 `monospacedDigit()` 폰트 modifier + 고정 너비 frame으로 메뉴바 흔들림 방지
- `PopoverRoot`는 두 화면 사이 전환만 담당. 화면별 로직은 각 Screen에 둠
- `DayDetailView`는 `StatisticsStore.aggregatedSessions(of:)`만 호출해서 표시
- `TitleField`는 두 모드를 가진다: **입력 모드**(Title이 비어 있을 때 — `TextField`) 와 **표시 모드**(Title이 있을 때 — 텍스트 + 편집 아이콘). 편집 아이콘을 누르면 입력 모드로 전환된다. `@FocusState`를 보유하고, idle 상태로 전환될 때 자동 포커스를 획득한다. `.onSubmit` 핸들러에서 `TimerStore.start()`를 호출하고 `@Environment(\.dismiss)`로 Popover를 닫는다
- `TimerControls`는 기본 컨트롤 영역(Start / Pause+Reset / Resume+Reset)과 항상 표시되는 보조 영역(End+Stats)을 모두 포함한다. End 버튼은 확인 다이얼로그 후 `TimerStore.endDay()`를 호출하고, Stats 버튼은 `PopoverRoot`에서 주입받은 콜백으로 화면 전환을 트리거한다
- `TimerScreen`은 `.onKeyPress(.space)` modifier를 통해 Space 키를 가로챈다. running이면 `TimerStore.pause()` 후 Popover 유지, paused이면 `TimerStore.start()` 후 `dismiss()` 호출. idle이거나 텍스트 필드에 포커스가 있으면 처리하지 않는다(SwiftUI 포커스 시스템이 자연히 텍스트 필드로 Space를 라우팅)

---

## 5. 데이터 흐름 시나리오

### 5.1 시작 버튼 클릭
```
TimerControls (View)
  → TimerStore.start()
    - activeSession이 nil이면 새로 생성
    - isRunning = true, lastTickAt = Date.now
    - Timer 구독 시작
    - Persistence.requestSave()
  → @Observable 변경 감지로 MenuBarLabel, TimeDisplayView 재렌더링
```

### 5.2 매 1초 tick
```
Timer.publish
  → TimerStore의 tick 핸들러
    - delta = Date.now - lastTickAt
    - activeSession.duration += delta
    - lastTickAt = Date.now
  → currentSessionDuration / totalDuration 파생값 갱신
  → View 자동 재렌더링 (1초 단위)
  → (저장은 매 tick마다 하지 않음. 다음 사용자 액션 또는 종료 시점에 묶어서 flush)
```

### 5.3 세션 리셋
```
TimerControls (View)
  → TimerStore.resetSession()
    - isRunning이면 stopTicking(), isRunning = false
    - activeSession이 있고 duration > 0이면 currentDay.sessions에 append
    - activeSession = nil (idle 복귀)
    - Persistence.requestSave()
  → @Observable 변경 감지로 TimerControls가 `Start` 버튼 1개로 갱신
  → MenuBarLabel이 00:00:00 텍스트로 업데이트
```

### 5.4 End (하루 마감)
```
TimerControls (End 버튼)
  → TimerStore.resetTotal()
    - activeSession이 있고 duration > 0이면 currentCycle.sessions에 append
    - currentCycle.endedAt = Date.now
    - onCycleClosed?(currentCycle) → StatisticsStore.appendClosedCycle() (단, 빈 주기면 skip)
    - currentCycle = 새 빈 Cycle, activeSession = nil, isRunning = false
    - onStateChanged?() → Persistence.requestSave()
  → 모든 화면 자동 갱신, MenuBarLabel은 00:00:00 텍스트 유지
```

### 5.5 시스템 슬립
```
NSWorkspace.willSleepNotification
  → SleepObserver onSleep
  → TimerStore.pause()
    - isRunning = false, Timer 구독 해제
    - Persistence.requestSave() (즉시 동기 flush — 슬립 직전이라 보장이 중요)
```

### 5.6 앱 재시작
```
HyperfocusApp.init
  → Persistence.load() → PersistedState
  → TimerStore(currentCycle:activeSession:) 초기화, isRunning은 항상 false (SPEC §9)
  → StatisticsStore(pastCycles:) 초기화
  → onCycleClosed / onStateChanged 콜백 연결
  → SleepObserver 시작
  → MenuBarExtra 표시
```

### 5.7 Space 키 — running → pause (Popover 유지)
```
Popover 열린 상태, running 중, TitleField 외 포커스
  → TimerScreen .onKeyPress(.space) 수신
  → TimerStore.pause()
    - isRunning = false, Timer 구독 해제
    - Persistence.requestSave()
  → Popover 유지 (dismiss 호출 없음)
  → MenuBarLabel: currentSessionDuration 고정된 채로 00:00:00 방향으로 멈춤 (텍스트 유지)
```

### 5.8 Space 키 — paused → resume + Popover 닫힘
```
Popover 열린 상태, paused 중
  → TimerScreen .onKeyPress(.space) 수신
  → TimerStore.start()
    - isRunning = true, lastTickAt = Date.now
    - Persistence.requestSave()
  → @Environment(\.dismiss) 호출 → Popover 닫힘
  → MenuBarLabel 시간 텍스트로 전환
```

### 5.9 Return 키 — idle, Title 입력 필드 포커스 → start + Popover 닫힘
```
Popover 열린 상태, idle, Title 입력 필드 포커스
  → TitleField .onSubmit 수신
  → TimerStore.start()
    - activeSession == nil이므로 새 세션 생성
    - isRunning = true, lastTickAt = Date.now
    - Persistence.requestSave()
  → @Environment(\.dismiss) 호출 → Popover 닫힘
  → MenuBarLabel 매초 증가 시작
```

### 5.10 새벽 6시 자동 마감
```
[앱 실행 중] 스케줄된 Timer가 새벽 6시에 발화
  → TimerStore.checkAndPerformRollover()
    - 마지막 저장 하루의 새벽 6시 경계를 넘었으면:
      - isRunning이면 pause() (자동 일시정지)
      - endDay() 호출 (종료 시각 = 해당 새벽 6시)
      - activeSession = nil, isRunning = false (idle)
    - 다음 새벽 6시로 Timer 재스케줄
    - Persistence.requestSave()
  → 모든 화면 자동 갱신

[앱 실행 시 / wake 시] HyperfocusApp 또는 SleepObserver.onWake
  → TimerStore.checkAndPerformRollover()
    - 현재 시각이 저장된 하루의 새벽 6시 경계를 넘었으면 endDay() 호출
    - 중간에 여러 6시를 건너뛴 경우에도 한 번만 마감 (빈 날 생성 없음)
    - 다음 새벽 6시로 Timer 스케줄
```

---

## 6. 저장 데이터 스키마(개념)

JSON 파일 한 개. 필드 의미 위주이며 정확한 키 이름은 구현 시 확정.

```
{
  "schemaVersion": 1,
  "pastDays": [
    {
      "id": "...",
      "startedAt": "ISO8601",
      "endedAt": "ISO8601",
      "sessions": [
        { "id": "...", "title": "리액트 공부", "duration": 5400.0, "startedAt": "..." },
        ...
      ]
    },
    ...
  ],
  "currentDay": {
    "id": "...",
    "startedAt": "ISO8601",
    "endedAt": null,
    "sessions": [ ... ]
  },
  "activeSession": {
    "id": "...",
    "title": "",
    "duration": 312.0,
    "startedAt": "..."
  }
}
```

- `activeSession`이 `null`이면 진행 중 세션 없음
- `isRunning`은 저장하지 않음 (재시작 시 항상 일시정지로 복원하므로 불필요)
- `lastTickAt`도 저장하지 않음 (재개 시 새로 설정)
- `currentDay.startedAt`으로 마지막 하루 시작 시각을 알 수 있어 rollover 체크에 활용

---

## 7. 테스트 전략

- `TimerStore` 테스트는 `Clock` mock으로 시간을 임의로 진행시켜 누적/리셋/rollover 동작 검증
- `Persistence` 테스트는 임시 디렉토리에 파일을 만들고 round-trip(write → read) 동등성 확인
- `SessionAggregation` 테스트는 순수 함수이므로 다양한 입력 조합에 대한 결과 비교
- `StatisticsStore.recentAverage` 테스트는 하루 0개/3개/7개/10개 경계 케이스 검증

UI/시스템 통합(메뉴바 표시, 슬립 알림 발화)은 수동 검증 영역으로 둔다.

---

## 8. 향후 변경 시 영향 범위 가이드

| 바꾸고 싶은 것 | 손대야 할 곳 |
| --- | --- |
| 시간 표시 형식 변경 | `Utilities/TimeFormatting.swift` 한 군데 |
| 일평균 기준 기간 변경 (7개 → 30개 등) | `StatisticsStore.recentAverage`의 기본 인자 |
| 자동 재개 활성화 | `SleepObserver.onWake`에서 `TimerStore.start()` 호출 추가 |
| 자동 마감 경계 시각 변경 (새벽 6시 → 자정 등) | `TimerStore.checkAndPerformRollover()`의 경계 시각 계산 로직 |
| 다른 저장 포맷 (SQLite 등) | `Services/Persistence.swift`만 교체. Store/View 변경 없음 |
| 통계 화면에 차트 추가 | `Views/Stats/` 하위에 새 컴포넌트 추가, Store 변경 불필요 |
| 타이머 상태 구분(idle/running/paused) 변경 | `TimerStore.swift` 액션 로직(`start/pause/resetSession/resetTotal`) + `TimerControls.swift` 버튼 분기 |
| 팝오버 키보드 단축키 동작 변경 | `Views/Timer/TimerScreen.swift`(Space 처리), `Views/Timer/TitleField.swift`(Return + 자동 포커스), SPEC §3.2 |
| Title 필드 모드 전환(입력↔표시) 동작 변경 | `Views/Timer/TitleField.swift`(모드 전환 로직), SPEC §4.1 |
| 타이머 화면 버튼 레이아웃 변경 | `Views/Timer/TimerControls.swift`(버튼 배치), SPEC §4.1 |
