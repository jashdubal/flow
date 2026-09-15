import Foundation
import AppKit
import Combine
import UserNotifications

/// UserNotifications requires a real bundle identity; debug runs from SwiftPM have none.
enum Notifications {
    static let available = Bundle.main.bundleIdentifier != nil
}

enum Phase {
    case flow, rest

    var title: String { self == .flow ? "Flow" : "Break" }
}

/// The clock. Owns phase, remaining time, and the session ring.
final class TimerEngine: ObservableObject {
    static let shared = TimerEngine()

    @Published private(set) var phase: Phase = .flow
    @Published private(set) var remaining: Int = 0
    @Published private(set) var running = false
    /// Flow sessions finished in the current ring, 0..<sessionCount.
    @Published private(set) var completed = 0

    private var timer: Timer?
    private var bag = Set<AnyCancellable>()
    private let settings = Settings.shared

    private init() {
        remaining = settings.flowMinutes * 60

        // Editing the duration of the phase you're sitting idle in should reset the clock.
        settings.$flowMinutes
            .dropFirst()
            .sink { [weak self] m in self?.durationChanged(.flow, minutes: m) }
            .store(in: &bag)
        settings.$breakMinutes
            .dropFirst()
            .sink { [weak self] m in self?.durationChanged(.rest, minutes: m) }
            .store(in: &bag)
        settings.$sessionCount
            .dropFirst()
            .sink { [weak self] n in
                guard let self else { return }
                if self.completed >= n { self.completed = 0 }
            }
            .store(in: &bag)
    }

    var total: Int {
        (phase == .flow ? settings.flowMinutes : settings.breakMinutes) * 60
    }

    var progress: Double {
        total > 0 ? 1 - Double(remaining) / Double(total) : 0
    }

    var clockText: String {
        let t = max(0, remaining)
        return String(format: "%02d:%02d", t / 60, t % 60)
    }

    // MARK: controls

    func toggle() { running ? pause() : start() }

    func start() {
        guard !running else { return }
        if remaining <= 0 { remaining = total }
        running = true
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        // .common keeps the clock alive while menus are tracking.
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func pause() {
        running = false
        timer?.invalidate()
        timer = nil
        Stats.shared.save()
    }

    /// Back to the start of the current phase.
    func reset() {
        pause()
        remaining = total
    }

    /// Abandon the ring entirely: back to a fresh flow phase, dots cleared.
    func resetAll() {
        pause()
        phase = .flow
        completed = 0
        remaining = total
    }

    /// Jump to the end of the current phase.
    func skip() { advance() }

    // MARK: internals

    private func tick() {
        if phase == .flow { Stats.shared.addFocus(seconds: 1) }
        remaining -= 1
        if remaining <= 0 { advance() }
    }

    private func durationChanged(_ p: Phase, minutes: Int) {
        guard phase == p, !running else { return }
        remaining = minutes * 60
    }

    private func advance() {
        let finished = phase
        if finished == .flow {
            Stats.shared.completeSession()
            completed = (completed + 1) % max(1, settings.sessionCount)
        }
        pause()
        phase = finished == .flow ? .rest : .flow
        remaining = total
        announce(finished: finished)

        let auto = finished == .flow ? settings.autoStartBreak : settings.autoStartFlow
        if auto { start() }
    }

    private func announce(finished: Phase) {
        if settings.playSound {
            NSSound(named: finished == .flow ? "Glass" : "Submarine")?.play()
        }
        // UNUserNotificationCenter hard-traps unless the process is in an app bundle,
        // so unbundled debug runs (`swift run`) skip notifications instead of crashing.
        guard settings.notify, Notifications.available else { return }
        let c = UNMutableNotificationContent()
        c.title = finished == .flow ? "FLOW COMPLETE" : "BREAK OVER"
        c.body = finished == .flow
            ? "\(settings.breakMinutes) minute break is up next."
            : "Back to it — \(settings.flowMinutes) minutes of flow."
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
