# Hyperfocus 구현 계획

[SPEC.md](./SPEC.md)의 요구사항을 [architecture.md](./architecture.md)의 구조로 구현하는
단계별 계획. 각 단계는 끝났을 때 무엇이 동작해야 하는지(verification)를 함께 명시한다.

기본 원칙:
- 한 단계가 끝나면 빌드가 통과하고 그 단계의 verification이 통과해야 다음으로 넘어간다
- UI보다 도메인 로직(Models / Stores / Services)을 먼저 만든다 — 테스트로 확신을 잡고 UI는 그 위에 얹는다
- 매 단계 끝에 commit 한 번

---

## Phase 0 — 프로젝트 스캐폴딩

**목표:** Xcode 프로젝트가 열리고, 메뉴바에 "Hello" 한 글자라도 떠야 한다.

**할 일:**
1. Xcode에서 macOS App 템플릿으로 새 프로젝트 생성, 경로 `/Users/jwchoi/Desktop/hyperfocus/Hyperfocus/`
   - Interface: SwiftUI, Language: Swift, Tests 포함
2. `Info.plist`에 `LSUIElement = YES` 추가 (Dock/앱 스위처 미노출)
3. Deployment Target: **macOS 14.0**
4. `HyperfocusApp.swift`를 `MenuBarExtra("Hyperfocus", systemImage: "stopwatch")` 골격으로 교체
   (기본 `WindowGroup`은 제거)
5. `architecture.md §3`의 폴더 트리대로 빈 폴더 생성 (`Models/`, `Stores/`, `Services/`, `Views/`, `Utilities/`)
6. `.gitignore` 추가 (Xcode 표준 무시 항목)

**검증:**
- `xcodebuild -scheme Hyperfocus build` 성공
- 앱 실행 시 메뉴바에 stopwatch 아이콘 표시, Dock에는 안 보임
- 클릭 시 빈 menu가 뜨거나 placeholder 표시

---

## Phase 1 — 도메인 모델 + 영속화

**목표:** 디스크에 상태를 쓰고 다시 읽어들이는 사이클이 동작한다 (UI는 아직 없음).

**할 일:**
1. `Models/Session.swift` — `Session: Codable, Identifiable` 작성
2. `Models/Day.swift` — `Day: Codable, Identifiable` 작성
3. `Models/PersistedState.swift` — 루트 구조 + `schemaVersion`
4. `Services/Clock.swift` — `protocol ClockProtocol { var now: Date { get } }` + `struct SystemClock` 기본 구현
5. `Services/Persistence.swift`
   - 저장 경로: `Application Support/Hyperfocus/state.json` (없으면 자동 생성)
   - `load() -> PersistedState` (파일 없으면 빈 상태)
   - `requestSave(_ state:)` — 디바운스(0.5s) + 백그라운드 큐
   - 종료 시 즉시 동기 flush를 위한 `saveNow(_ state:)`
6. `HyperfocusTests/PersistenceTests.swift` — 임시 디렉토리에 round-trip 테스트

**검증:**
- 모든 테스트 통과
- 디버그 빌드를 한 번 실행했다 종료하면 `state.json`이 빈 객체로 생성되어 있음

---

## Phase 2 — TimerStore (핵심 로직)

**목표:** 코드만으로 SPEC §5의 모든 동작이 검증된다.

**할 일:**
1. `Stores/TimerStore.swift` — `@Observable` 클래스
   - 보유: `currentDay: Day`, `activeSession: Session?`, `isRunning: Bool`, `lastTickAt: Date?`
   - 액션: `start()`, `pause()`, `pauseForSleep()`, `resetSession()`, `endDay()`, `updateActiveSessionName(_:)`
   - 파생: `currentSessionDuration`, `totalDuration`
   - 콜백: `onDayClosed: ((Day) -> Void)?`, `onStateChanged: (() -> Void)?`
2. tick 메커니즘: `Timer.publish(every: 1.0, on: .main, in: .common)` 구독,
   매 tick에서 `delta = clock.now - lastTickAt` 누적
3. 상태 변경마다 `onStateChanged?()` 호출 → `HyperfocusApp`이 `Persistence.requestSave()` 실행
4. `HyperfocusTests/TimerStoreTests.swift`
   - `ClockProtocol` mock(`MockClock`)으로 시간 임의 진행
   - SPEC §5 + §10 엣지 케이스 표의 각 행을 테스트 케이스화
   - 특히: 누적 0 세션이 기록되지 않는 것, 세션 리셋 후 idle 복귀(activeSession = nil, isRunning = false), `endDay` 시 빈 하루 미기록

**검증:**
- 모든 단위 테스트 통과
- SPEC §10 엣지 케이스 표의 모든 행이 테스트로 커버됨

---

## Phase 3 — StatisticsStore + 합산 유틸

**목표:** 과거 주기 데이터로 통계 화면이 필요로 하는 모든 값이 계산된다.

**할 일:**
1. `Utilities/SessionAggregation.swift`
   - 입력: `[Session]`, 출력: `[(title: String, total: TimeInterval)]` (시간 내림차순)
   - SPEC §6.2~6.3 규칙대로 빈/공백 Title은 `(Untitled)`로 정규화, 대소문자 구분
2. `Utilities/TimeFormatting.swift`
   - `formatHHMMSS(_ seconds: TimeInterval) -> String`
   - `formatHumanShort(_ seconds: TimeInterval) -> String` (예: `5h 42m`)
3. `Stores/StatisticsStore.swift` — `@Observable` 클래스
   - 보유: `pastDays: [Day]` (최신이 앞)
   - 액션: `appendClosedDay(_ day: Day)` — 빈 하루(세션 0개)면 무시
   - 파생: `recentAverage(count: Int = 7) -> (average: TimeInterval, sampleSize: Int)?`
   - 헬퍼: `aggregatedSessions(of: Day) -> [AggregatedSession]`, `aggregatedSessionsIncluding(day:active:) -> [AggregatedSession]`
4. `TimerStore.onDayClosed` 콜백에서 `StatisticsStore.appendClosedDay()` 호출 (`HyperfocusApp`에서 연결)
5. 테스트:
   - `SessionAggregationTests.swift` — 빈 이름/공백/대소문자/합산 케이스
   - `AverageCalculationTests.swift` — 0/3/7/10개 하루 경계
   - `TimeFormattingTests.swift` — 0초/59초/1시간/100시간

**검증:**
- 모든 단위 테스트 통과
- `endDay` 호출 시 `StatisticsStore.pastDays`가 올바르게 갱신됨 (TimerStore 테스트에 통합 시나리오 추가)

---

## Phase 4 — 메뉴바 + Popover 셸

**목표:** 메뉴바 라벨이 상태에 따라 토글되고, 클릭 시 빈 Popover가 뜬다.

**할 일:**
1. `HyperfocusApp.swift` 업데이트
   - 앱 시작 시 `Persistence.load()` → `TimerStore`/`StatisticsStore`에 주입
   - 상태 로드 직후 `TimerStore.checkAndPerformRollover()` 호출 (앱 종료 중 새벽 6시를 넘긴 경우 처리)
   - `MenuBarExtra { PopoverRoot() } label: { MenuBarLabel() }`
   - `.menuBarExtraStyle(.window)` 적용
   - 종료 시 `Persistence.saveNow` 훅
2. `Views/MenuBarLabel.swift`
   - 항상 이름(위) + 타이머(아래) 두 줄로 표시. 아이콘 전환 없음 (SPEC §3.1)
   - 이름이 없거나 공백이면 `(Untitled)` 표시, idle이면 타이머는 `00:00:00`
   - `NSImage`에 두 줄 직접 드로잉, `isTemplate = true`로 라이트/다크 자동 대응
   - 이름이 타이머(`HH:MM:SS`) 너비 초과 시 `…` 말줄임. 아이템 너비는 타이머 너비+여백으로 고정
3. `Views/PopoverRoot.swift`
   - 내부 상태로 현재 화면(`timer` / `stats`) 보관
   - 두 placeholder 뷰만 두고 화면 전환 토글 동작 확인

**검증:**
- 앱 실행 → 메뉴바 `00:00:00` 텍스트 표시
- (TimerStore를 수동으로 `isRunning = true` 한 상태로 잠시 띄워서) 메뉴바 라벨이 `00:00:01`, `00:00:02`로 갱신
- 클릭 시 popover-style 윈도우가 떴다 닫혔다 함
- 메뉴바 좌우 다른 아이콘들이 시간 자릿수에 영향받지 않음

---

## Phase 5 — 타이머 화면 UI

**목표:** SPEC §4.1과 §5의 모든 사용자 액션을 popover에서 직접 수행할 수 있다.

**할 일:**
1. `Views/Timer/TimeDisplayView.swift`
   - Current / Today 두 줄을 동일한 폰트 스타일로 표시 (`formatHHMMSS`)
2. `Views/Timer/TitleField.swift`
   - Title이 비어 있으면 `TextField`(placeholder: "Title"), 있으면 텍스트 + 편집 아이콘
   - 편집 아이콘 탭 시 입력 모드로 전환
   - `onChange`로 `TimerStore.updateActiveSessionName(_:)` 호출 (Store 내부에서 디바운스됨)
3. `Views/Timer/TimerControls.swift`
   - 기본 버튼 영역(위 divider): idle→`[Start]`, running→`[Pause][Reset]`, paused→`[Resume][Reset]`
   - 보조 버튼 영역(위 divider, 항상): `[End]`+`[Stats]` 나란히
   - End 누르면 `TimerStore.endDay()` 호출, Stats는 콜백으로 화면 전환
4. `Views/Timer/TimerScreen.swift`
   - 위 컴포넌트 조립
5. `PopoverRoot`의 timer 케이스를 `TimerScreen()`으로 교체

**검증 (수동, SPEC §5 시나리오대로):**
- Start → Current/Today 두 줄 모두 증가, 메뉴바 갱신
- Title 입력 → 타이핑 후 0.5초 이내 디스크 저장 확인 (`state.json` 모니터)
- Title 비어있으면 input 필드, 입력 후엔 텍스트+편집 아이콘 표시 확인
- Pause → 시간 멈춤, 메뉴바 라벨 현재 시간 고정
- Reset → Current 0, Today는 마감 세션 합계, Title 필드 초기화, idle 상태 복귀 (`Start` 버튼 단독 표시)
- End → Current/Today 둘 다 0, 메뉴바 `00:00:00` 텍스트 유지
- End 후 상태가 디스크에도 반영됨

---

## Phase 6 — 통계 화면 UI

**목표:** SPEC §4.2, §4.3, §7의 모든 표시 규칙이 화면에 그려진다.

**할 일:**
1. `Views/Stats/AverageSummaryView.swift`
   - `StatisticsStore.recentAverage()`를 받아 표시
   - 0개일 때 안내 문구, 7개 미만일 때 sample size 표기
2. `Views/Stats/CurrentDayCardView.swift`
   - 오늘 하루의 시작 일시, 누적, 합산 세션 리스트 (`aggregatedSessionsIncluding(day:active:)`)
   - 진행 중 세션은 합산에 포함시켜야 함 (오늘 하루 한정)
3. `Views/Stats/PastDayRowView.swift`
   - 한 날 요약 (시작/종료/총합)
   - 탭 시 detail view로 전환
4. `Views/Stats/DayDetailView.swift`
   - 해당 날의 합산 세션 리스트, 시간 내림차순
   - 뒤로 가기 버튼
5. `Views/Stats/StatsScreen.swift`
   - 위에서 아래로 요약 → 오늘 카드 → 지난 날 목록 스택
   - 상단에 `[타이머로]` 돌아가기 버튼
6. `PopoverRoot`의 stats 케이스를 `StatsScreen()`으로 교체, detail navigation은 PopoverRoot가 관리

**검증 (수동):**
- 가짜 데이터 시드 (직접 JSON 작성)로 과거 날 3개/8개 상태에서 진입
- 합산이 SPEC §6.3 규칙대로 맞음 (대소문자 다른 Title은 분리, 공백만 Title은 `(Untitled)`로 묶임)
- 시간 내림차순 정렬 확인
- 지난 날 클릭 → 상세 → 뒤로 가기 흐름 자연스러움
- 평균 표시가 sample size 표기 포함해 정확

---

## Phase 7 — 슬립 연동

**목표:** 시스템 슬립 시 자동 일시정지, 깨어났을 때 자동 재개 없음 (SPEC §8).

**할 일:**
1. `Services/SleepObserver.swift`
   - 생성자에 `onSleep: () -> Void`, `onWake: () -> Void` 클로저
   - `.willSleepNotification` → `onSleep`, `.didWakeNotification` → `onWake`
   - deinit에서 removeObserver
2. `HyperfocusApp`에서 `SleepObserver(onSleep: { timerStore.pause() }, onWake: { timerStore.checkAndPerformRollover() })` 보관
3. `TimerStore.pause()`가 슬립으로 호출될 때도 `Persistence.saveNow`로 즉시 flush되도록 분기 추가 (인자로 `flushImmediately: Bool`)

**검증 (수동):**
- 스탑워치 실행 중 → 맥북 뚜껑 닫음 → 잠시 후 열기 → 일시정지 상태, 닫혀 있던 시간이 가산되지 않음
- 깨어나도 자동 재개되지 않음 (사용자가 다시 시작 눌러야 함)
- `state.json`에 슬립 직전 상태가 저장되어 있음

---

## Phase 8 — 통합 검증 + 폴리시

**목표:** SPEC 전체를 손으로 한 바퀴 돌려 회귀가 없는지 확인한다.

**할 일:**
1. SPEC §10 엣지 케이스 표를 체크리스트로 만들어 모두 수동 확인
2. SPEC §4의 UI 구성 순서/라벨/버튼 명칭(Title, Current, Today, Start, Pause, Resume, Reset, End, Stats)이 모두 일치하는지 검수
3. 메뉴바 라벨 두 줄 표시 확인: idle → `(Untitled)/00:00:00`, 이름 있음 → 이름/타이머, 긴 이름 → `…` 말줄임
4. 메뉴바 라벨 폭 안정성 한 번 더 확인 (1자리 시→10자리 시 전환 시 다른 메뉴바 아이콘 움직임 없음)
5. 앱 종료 후 재시작 시 SPEC §9대로 일시정지 상태로 복원되는지 확인
6. 빈 상태 / 첫 실행 경험 한 번 더 검수
7. README 한 줄이라도 추가 (실행 방법, SPEC/architecture/plan 문서 링크)
8. 코드 컬러: 사용 안 하는 import / 죽은 코드 제거

**검증:**
- SPEC §10 체크리스트 전부 통과
- 단위 테스트 전부 통과
- 빌드 경고 0개

---

## Phase 9 — 키보드 단축키 및 포커스 UX

**목표:** SPEC §3.2의 Space 키 단축키와 §4.1의 자동 포커스 + Return 키 시작 동작이 구현된다.

**할 일:**
1. `Views/Timer/TitleField.swift`
   - `@FocusState`를 추가하고 `TimerStore`가 idle 상태일 때 자동 포커스 획득
   - `.onSubmit` 핸들러: `TimerStore.start()` 호출 후 `@Environment(\.dismiss)`로 Popover 닫기
2. `Views/Timer/TimerScreen.swift`
   - `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` 로 Space 키 가로채기
     (SwiftUI `.onKeyPress`는 포커스 체인 신뢰성 문제로 사용하지 않음)
     - running → `TimerStore.pause()`, Popover 유지
     - paused → `TimerStore.start()` 후 `dismiss()` 실행
     - idle → 이벤트 통과, 텍스트 필드가 공백 문자로 처리

**검증 (수동):**
- Popover를 열면 idle 상태일 때 Title 입력 필드에 커서(커서 깜빡임)가 자동으로 들어옴
- idle, Title 입력 필드 포커스 상태에서 Space 키 → 필드에 공백 입력만 됨 (타이머 제어 없음)
- idle, Title 입력 필드 포커스 상태에서 Return 키 → 세션 시작 + Popover 닫힘
- running 상태에서 Popover 열기 → Space 키 → Pause, Popover 유지됨
- paused 상태에서 Popover 열기 → Space 키 → Resume + Popover 닫힘
- running/paused 상태에서 Popover 열기 → Title 필드에 자동 포커스 없음
- running/paused 상태, Title 있음 → 편집 아이콘 클릭 → 입력 필드로 전환, Space 키 → 필드에 공백 입력만 됨

---

## 단계 의존 관계

```
Phase 0 (스캐폴딩)
    │
    ├── Phase 1 (Models + Persistence) ──┐
    │                                    │
    └── Phase 4 (MenuBar 셸)             │
            │                            │
            │   ┌── Phase 2 (TimerStore) ┘
            │   │
            │   └── Phase 3 (StatisticsStore)
            │           │
            ├───────────┴── Phase 5 (Timer UI)
            │
            └────────────── Phase 6 (Stats UI)
                                  │
                                  └── Phase 7 (Sleep)
                                            │
                                            └── Phase 8 (통합)
                                                      │
                                                      └── Phase 9 (키보드 단축키 + 포커스 UX)
```

- Phase 1과 Phase 4는 서로 독립이라 병행 가능, 그러나 Phase 5/6은 Phase 2/3 완료 후에 들어가는 게 안전
- Phase 7은 가장 마지막에 붙여야 다른 단계의 디버깅이 방해받지 않음 (테스트 중 의도치 않은 일시정지 방지)

---

## 완료 기준 (Definition of Done)

이 앱이 "완성"되었다고 부를 수 있는 조건:

1. SPEC.md의 모든 기능 동작이 popover에서 직접 사용 가능
2. SPEC §10 엣지 케이스 표가 모두 의도대로 동작
3. SPEC §11 (Out of Scope)에 명시되지 않은 기능은 포함되지 않음
4. 단위 테스트가 모두 통과
5. 빌드 경고 0개
6. 앱 재시작 후 상태가 SPEC §9대로 복원됨
7. 슬립/깨어남 사이클이 SPEC §8대로 동작함
