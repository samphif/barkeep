import Foundation
import Testing
@testable import Barkeep

struct RehideClockTests {
    private let start = Date(timeIntervalSince1970: 0)

    private func ticks(delay: TimeInterval, _ samples: [(at: TimeInterval, inUse: Bool)]) -> [Bool] {
        var clock = RehideClock(delay: delay, lastActivity: start)
        return samples.map { clock.tick(now: start.addingTimeInterval($0.at), inUse: $0.inUse) }
    }

    @Test func expiresAfterDelayWhenIdle() {
        #expect(ticks(delay: 10, [(5, false), (10, false)]) == [false, true])
    }

    @Test func neverExpiresWhileInUse() {
        #expect(ticks(delay: 10, [(30, true), (60, true)]) == [false, false])
    }

    @Test func activityRestartsTheCountdown() {
        #expect(ticks(delay: 10, [(8, true), (15, false), (18, false)]) == [false, false, true])
    }
}

@MainActor
struct RehideDelayTests {
    @Test func neverHasNoSeconds() {
        #expect(RehideDelay.never.seconds == nil)
        #expect(RehideDelay.tenSeconds.seconds == 10)
    }

    @Test func readsDelaysStoredByEarlierVersionsAsDoubles() throws {
        let suite = "BarkeepTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = Settings(defaults: defaults)

        #expect(settings.rehideDelay == .tenSeconds)
        defaults.set(30.0, forKey: "rehideDelay")
        #expect(settings.rehideDelay == .thirtySeconds)
        defaults.set(0.0, forKey: "rehideDelay")
        #expect(settings.rehideDelay == .never)
        defaults.set(42.0, forKey: "rehideDelay")
        #expect(settings.rehideDelay == .tenSeconds)
    }
}
