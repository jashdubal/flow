import AppKit
import ServiceManagement

/// The ⋮ / status-item menu. Rebuilt on each pop-up so state marks stay correct.
final class AppMenu: NSObject, NSMenuDelegate {
    static let shared = AppMenu()

    private let settings = Settings.shared
    private let engine = TimerEngine.shared

    func build() -> NSMenu {
        let m = NSMenu()
        m.autoenablesItems = false

        m.addItem(item("About Flow", #selector(about)))
        m.addItem(.separator())

        m.addItem(submenu("Flow Duration", presets: Settings.flowPresets,
                          current: settings.flowMinutes, action: #selector(setFlow(_:)), unit: "minutes"))
        m.addItem(submenu("Break Duration", presets: Settings.breakPresets,
                          current: settings.breakMinutes, action: #selector(setBreak(_:)), unit: "minutes"))
        m.addItem(submenu("Session Count", presets: Settings.sessionPresets,
                          current: settings.sessionCount, action: #selector(setSessions(_:)), unit: "sessions"))

        m.addItem(.separator())
        m.addItem(item(engine.running ? "Pause" : "Start", #selector(toggle), key: " "))
        m.addItem(item("Skip Phase", #selector(skip)))
        m.addItem(item("Reset Session", #selector(resetAll), key: "r"))

        m.addItem(.separator())
        m.addItem(settingsMenu())
        m.addItem(item("Statistics…", #selector(showStats), key: "s"))

        m.addItem(.separator())
        m.addItem(item("Quit Flow", #selector(quit), key: "q"))
        return m
    }

    /// Pops the menu up beneath the pointer, anchored in the timer window.
    func popUpAtCursor() {
        let menu = build()
        guard let win = WindowManager.shared.timerWindow, let content = win.contentView else {
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
            return
        }
        let inWindow = win.convertPoint(fromScreen: NSEvent.mouseLocation)
        let p = content.convert(inWindow, from: nil)
        menu.popUp(positioning: nil, at: NSPoint(x: p.x - 12, y: p.y - 10), in: content)
    }

    // MARK: construction helpers

    private func item(_ title: String, _ sel: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        i.target = self
        return i
    }

    private func submenu(_ title: String, presets: [Int], current: Int,
                         action: Selector, unit: String) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let sub = NSMenu()
        sub.autoenablesItems = false
        var values = presets
        if !values.contains(current) { values.append(current); values.sort() }
        for v in values {
            let i = NSMenuItem(title: "\(v) \(unit)", action: action, keyEquivalent: "")
            i.target = self
            i.tag = v
            i.state = v == current ? .on : .off
            sub.addItem(i)
        }
        sub.addItem(.separator())
        let other = NSMenuItem(title: "Other…", action: action, keyEquivalent: "")
        other.target = self
        other.tag = -1
        other.representedObject = title
        sub.addItem(other)
        parent.submenu = sub
        return parent
    }

    private func settingsMenu() -> NSMenuItem {
        let parent = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        sub.autoenablesItems = false
        func toggleItem(_ title: String, _ on: Bool, _ sel: Selector) -> NSMenuItem {
            let i = NSMenuItem(title: title, action: sel, keyEquivalent: "")
            i.target = self
            i.state = on ? .on : .off
            return i
        }
        sub.addItem(toggleItem("Auto-start breaks", settings.autoStartBreak, #selector(tAutoBreak)))
        sub.addItem(toggleItem("Auto-start next flow", settings.autoStartFlow, #selector(tAutoFlow)))
        sub.addItem(.separator())
        sub.addItem(toggleItem("Play sound on finish", settings.playSound, #selector(tSound)))
        sub.addItem(toggleItem("Show notifications", settings.notify, #selector(tNotify)))
        sub.addItem(toggleItem("Show countdown in menu bar", settings.showTimeInMenuBar, #selector(tMenuBarTime)))
        sub.addItem(.separator())
        sub.addItem(toggleItem("Launch at login", launchAtLoginEnabled, #selector(tLaunchAtLogin)))
        parent.submenu = sub
        return parent
    }

    // MARK: actions

    @objc private func toggle() { engine.toggle() }
    @objc private func skip() { engine.skip() }
    @objc private func resetAll() { engine.resetAll() }
    @objc private func showStats() { WindowManager.shared.showStats() }
    @objc private func quit() { Stats.shared.save(); NSApp.terminate(nil) }

    @objc private func about() {
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSAttributedString(
            string: "A minimalist flow timer with a focus heatmap.\nStats live in ~/Library/Application Support/Flow.",
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)])
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    @objc private func setFlow(_ sender: NSMenuItem) {
        applyValue(sender, range: 1...480, prompt: "Flow duration in minutes:") { self.settings.flowMinutes = $0 }
    }
    @objc private func setBreak(_ sender: NSMenuItem) {
        applyValue(sender, range: 1...120, prompt: "Break duration in minutes:") { self.settings.breakMinutes = $0 }
    }
    @objc private func setSessions(_ sender: NSMenuItem) {
        applyValue(sender, range: 1...12, prompt: "Sessions before the ring resets:") { self.settings.sessionCount = $0 }
    }

    /// Preset items carry their value in `tag`; tag -1 means "Other…" and prompts.
    private func applyValue(_ sender: NSMenuItem, range: ClosedRange<Int>,
                            prompt: String, assign: (Int) -> Void) {
        if sender.tag > 0 { assign(sender.tag); return }
        guard let n = askNumber(prompt: prompt, range: range) else { return }
        assign(n)
    }

    private func askNumber(prompt: String, range: ClosedRange<Int>) -> Int? {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = "Custom Value"
        a.informativeText = "\(prompt) (\(range.lowerBound)–\(range.upperBound))"
        a.addButton(withTitle: "Set")
        a.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        a.accessoryView = field
        a.window.initialFirstResponder = field
        guard a.runModal() == .alertFirstButtonReturn, let n = Int(field.stringValue) else { return nil }
        return min(max(n, range.lowerBound), range.upperBound)
    }

    @objc private func tAutoBreak() { settings.autoStartBreak.toggle() }
    @objc private func tAutoFlow() { settings.autoStartFlow.toggle() }
    @objc private func tSound() { settings.playSound.toggle() }
    @objc private func tNotify() { settings.notify.toggle() }
    @objc private func tMenuBarTime() { settings.showTimeInMenuBar.toggle() }

    // MARK: login item

    private var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @objc private func tLaunchAtLogin() {
        do {
            if launchAtLoginEnabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            // Unsigned/dev builds can't register a login item; surface it rather than failing silently.
            let a = NSAlert()
            a.messageText = "Couldn't change the login item"
            a.informativeText = error.localizedDescription
            a.runModal()
        }
    }
}
