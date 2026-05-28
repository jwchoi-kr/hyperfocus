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

    // decodeIfPresent: 기존 state.json에 이 키가 없어도 빈 목록으로 안전하게 마이그레이션
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        currentDay = try c.decode(Day.self, forKey: .currentDay)
        pastDays = try c.decode([Day].self, forKey: .pastDays)
        activeSession = try c.decodeIfPresent(Session.self, forKey: .activeSession)
        focusBlocklist = try c.decodeIfPresent(FocusBlocklist.self, forKey: .focusBlocklist) ?? FocusBlocklist()
    }
}
