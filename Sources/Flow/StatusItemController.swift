import AppKit
import Combine
import SwiftUI

/// The menu bar presence: a drawn glyph plus an optional live countdown.
final class StatusItemController {
    private let item: NSStatusItem
    private var bag = Set<AnyCancellable>()
    private let engine = TimerEngine.shared
    private let settings = Settings.shared

    init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(clicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // Repaint on every relevant change.
        engine.objectWillChange
            .merge(with: settings.objectWillChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.refresh() }
            .store(in: &bag)
        refresh()
    }

    private func refresh() {
        guard let b = item.button else { return }
        b.attributedTitle = StatusItemController.title(
            clock: settings.showTimeInMenuBar ? engine.clockText : nil,
            running: engine.running)
        b.toolTip = "Flow — \(engine.phase.title) \(engine.clockText)"
    }

    /// A lowercase italic "ƒ" — focus, set like a camera aperture mark — ahead of the clock.
    /// It dims while paused, which is the only feedback when the clock is hidden.
    /// labelColor keeps it legible in both light and dark menu bars.
    private static func title(clock: String?, running: Bool) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let mark = NSFont(name: "Menlo-BoldItalic", size: 13)
            ?? NSFont.systemFont(ofSize: 13, weight: .semibold)
        out.append(NSAttributedString(string: "\u{0192}", attributes: [
            .font: mark,
            .foregroundColor: running ? NSColor.labelColor : NSColor.secondaryLabelColor,
            // The glyph is tall and sits low; nudge it onto the clock's baseline.
            .baselineOffset: -0.5,
        ]))
        if let clock {
            out.append(NSAttributedString(string: "  " + clock, attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.labelColor,
            ]))
        }
        return out
    }

    /// Left click shows/hides the window, right click starts and pauses,
    /// control- or option-click opens the menu.
    @objc private func clicked() {
        guard let event = NSApp.currentEvent else {
            WindowManager.shared.toggleWindow()
            return
        }
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // Checked before the button, since a control-click arrives as a right click.
        if mods.contains(.control) || mods.contains(.option) {
            showMenu()
        } else if event.type == .rightMouseUp {
            engine.toggle()
        } else {
            WindowManager.shared.toggleWindow()
        }
    }

    /// NSStatusItem only opens a menu it owns, so attach it for the length of the click.
    private func showMenu() {
        item.menu = AppMenu.shared.build()
        item.button?.performClick(nil)
        item.menu = nil
    }

}
