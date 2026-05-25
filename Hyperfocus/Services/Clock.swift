import Foundation

protocol ClockProtocol {
    var now: Date { get }
}

struct SystemClock: ClockProtocol {
    var now: Date { Date() }
}
