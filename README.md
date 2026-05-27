# Hyperfocus

macOS 메뉴바 스탑워치 앱. 작업 세션을 기록하고 하루·주·월 단위 작업 시간 통계를 확인한다.

## 기능

**타이머**
- 메뉴바에서 즉시 Start / Pause / Resume / End
- 세션 이름(Title) 입력 — 언제든 수정 가능
- 메뉴바 라벨: 세션 이름(위) + 현재 세션 시간(아래) 두 줄 항상 표시
- Current(현재 세션) / Today(하루 누적) 이중 타이머
- Space 키로 Pause ↔ Resume 전환 (Popover가 열린 상태에서)

**자동 관리**
- 매일 새벽 6시 자동 마감 — 앱이 꺼져 있거나 슬립 중이었어도 재실행 시 처리
- 시스템 슬립 시 자동 일시정지, 깨어난 후 수동 재개
- 앱 종료·재시작 후에도 진행 중 세션 및 기록 완전 복원

**통계**
- Today: 오늘 세션 목록 (오늘 전체 대비 %)
- This Week: 이번 주 날짜별 바 차트
- This Month: 월간 캘린더 — 날짜 탭 시 해당 날 상세 확인
- 세션 이름 인라인 편집 및 삭제 (오늘·과거 모두)

## 요구사항

- macOS 14.0 이상
- Xcode 15 이상

## 빌드

```
open Hyperfocus.xcodeproj
```

Xcode에서 `Hyperfocus` 스킴을 선택하고 Run(⌘R).

코드 사이닝은 "Sign to Run Locally"로 충분하다.

## 데이터 저장

모든 데이터는 기기 로컬에만 저장된다.

```
~/Library/Application Support/Hyperfocus/state.json
```

## 기술 스택

- Swift / SwiftUI / AppKit
- `MenuBarExtra` (`.window` 스타일)
- Swift Observation (`@Observable`)
- Swift Charts
- XCTest 단위 테스트
- 외부 의존성 없음
