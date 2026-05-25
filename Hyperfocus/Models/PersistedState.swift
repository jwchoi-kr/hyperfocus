import Foundation

struct PersistedState: Codable {
    var schemaVersion: Int
    var currentDay: Day
    var pastDays: [Day]
    var activeSession: Session?

    init(
        schemaVersion: Int = 1,
        currentDay: Day = Day(),
        pastDays: [Day] = [],
        activeSession: Session? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.currentDay = currentDay
        self.pastDays = pastDays
        self.activeSession = activeSession
    }
}
