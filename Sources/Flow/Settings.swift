import Foundation
import Combine

/// User-tunable durations and behaviour, mirrored into UserDefaults.
final class Settings: ObservableObject {
    static let shared = Settings()

    @Published var flowMinutes: Int      { didSet { d.set(flowMinutes, forKey: "flowMinutes") } }
    @Published var breakMinutes: Int     { didSet { d.set(breakMinutes, forKey: "breakMinutes") } }
    @Published var sessionCount: Int     { didSet { d.set(sessionCount, forKey: "sessionCount") } }
    @Published var autoStartBreak: Bool  { didSet { d.set(autoStartBreak, forKey: "autoStartBreak") } }
    @Published var autoStartFlow: Bool   { didSet { d.set(autoStartFlow, forKey: "autoStartFlow") } }
    @Published var playSound: Bool       { didSet { d.set(playSound, forKey: "playSound") } }
    @Published var notify: Bool          { didSet { d.set(notify, forKey: "notify") } }
    @Published var showTimeInMenuBar: Bool { didSet { d.set(showTimeInMenuBar, forKey: "showTimeInMenuBar") } }

    static let flowPresets  = [15, 20, 25, 30, 45, 50, 60, 90]
    static let breakPresets = [3, 5, 10, 15, 20, 30]
    static let sessionPresets = [2, 3, 4, 5, 6, 8]

    private let d = UserDefaults.standard

    private init() {
        d.register(defaults: [
            "flowMinutes": 50, "breakMinutes": 5, "sessionCount": 4,
            "autoStartBreak": false, "autoStartFlow": false,
            "playSound": true, "notify": true, "showTimeInMenuBar": true,
        ])
        flowMinutes = d.integer(forKey: "flowMinutes")
        breakMinutes = d.integer(forKey: "breakMinutes")
        sessionCount = d.integer(forKey: "sessionCount")
        autoStartBreak = d.bool(forKey: "autoStartBreak")
        autoStartFlow = d.bool(forKey: "autoStartFlow")
        playSound = d.bool(forKey: "playSound")
        notify = d.bool(forKey: "notify")
        showTimeInMenuBar = d.bool(forKey: "showTimeInMenuBar")
    }
}
