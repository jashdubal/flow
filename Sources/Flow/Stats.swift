import Foundation
import Combine

/// Focus seconds bucketed by calendar day, persisted as JSON in Application Support.
final class Stats: ObservableObject {
    static let shared = Stats()

    /// "yyyy-MM-dd" -> focused seconds.
    @Published private(set) var seconds: [String: Int] = [:]
    /// "yyyy-MM-dd" -> completed flow sessions.
    @Published private(set) var sessions: [String: Int] = [:]

    private let url: URL
    private var pendingSave = false

    static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(_ date: Date) -> String { keyFormatter.string(from: date) }

    private init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Flow", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        url = base.appendingPathComponent("stats.json")
        load()
    }

    // MARK: recording

    /// Called once per timer tick while a flow phase runs.
    func addFocus(seconds delta: Int, on date: Date = Date()) {
        let k = Stats.key(date)
        seconds[k, default: 0] += delta
        scheduleSave()
    }

    func completeSession(on date: Date = Date()) {
        let k = Stats.key(date)
        sessions[k, default: 0] += 1
        scheduleSave()
    }

    func reset() {
        seconds = [:]
        sessions = [:]
        save()
    }

    // MARK: queries

    func minutes(on date: Date) -> Int { (seconds[Stats.key(date)] ?? 0) / 60 }

    var todayMinutes: Int { minutes(on: Date()) }

    var totalMinutes: Int { seconds.values.reduce(0, +) / 60 }

    var totalSessions: Int { sessions.values.reduce(0, +) }

    /// Minutes focused within the last `days` days, today inclusive.
    /// Keys are ISO dates, so a string comparison beats parsing every one of them.
    func minutes(lastDays days: Int) -> Int {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -(days - 1), to: cal.startOfDay(for: Date()))!
        let cutoff = Stats.key(start)
        return seconds.reduce(0) { sum, entry in
            entry.key >= cutoff ? sum + entry.value : sum
        } / 60
    }

    /// Consecutive days with any focus, counting back from today (or yesterday if today is empty).
    var streak: Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date())
        if (seconds[Stats.key(day)] ?? 0) == 0 {
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        var n = 0
        while (seconds[Stats.key(day)] ?? 0) > 0 {
            n += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return n
    }

    var bestDayMinutes: Int { (seconds.values.max() ?? 0) / 60 }

    /// Years that actually hold focus time, oldest first.
    var years: [Int] {
        let ys = seconds.compactMap { key, value -> Int? in
            value > 0 ? Int(key.prefix(4)) : nil
        }
        return Array(Set(ys)).sorted()
    }

    /// Total focus minutes within a calendar year.
    func minutes(inYear year: Int) -> Int {
        let prefix = String(year)
        return seconds.reduce(0) { sum, e in
            e.key.hasPrefix(prefix) ? sum + e.value : sum
        } / 60
    }

    // MARK: persistence

    private struct Payload: Codable {
        var seconds: [String: Int]
        var sessions: [String: Int]
    }

    private func load() {
        guard let data = try? Data(contentsOf: url),
              let p = try? JSONDecoder().decode(Payload.self, from: data) else { return }
        seconds = p.seconds
        sessions = p.sessions
    }

    /// Ticks arrive every second; coalesce writes so we touch disk at most every 10s.
    private func scheduleSave() {
        guard !pendingSave else { return }
        pendingSave = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.pendingSave = false
            self?.save()
        }
    }

    func save() {
        let p = Payload(seconds: seconds, sessions: sessions)
        guard let data = try? JSONEncoder().encode(p) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
