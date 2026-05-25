import Foundation

struct PersistedState: Codable {
    var schemaVersion: Int
    var currentCycle: Cycle
    var pastCycles: [Cycle]
    var activeSession: Session?

    init(
        schemaVersion: Int = 1,
        currentCycle: Cycle = Cycle(),
        pastCycles: [Cycle] = [],
        activeSession: Session? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.currentCycle = currentCycle
        self.pastCycles = pastCycles
        self.activeSession = activeSession
    }
}
