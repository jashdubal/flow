import AppKit
import SwiftUI
import Combine

enum Mode { case timer, stats }

final class AppState: ObservableObject {
    static let shared = AppState()
    @Published fileprivate(set) var mode: Mode = .timer
    private init() {}
}

/// Root of the single window: the compact timer, or the statistics panel it expands into.
struct RootView: View {
    @ObservedObject var state = AppState.shared

    var body: some View {
        Group {
            switch state.mode {
            case .timer: TimerView()
            case .stats: StatsView()
            }
        }
        .background(Theme.void)
    }
}

/// Owns the app's one window and the resize between its two modes.
final class WindowManager: NSObject, NSWindowDelegate {
    static let shared = WindowManager()

    private(set) var timerWindow: NSWindow?

    private let timerSize = NSSize(width: 360, height: 212)
    private let statsSize = NSSize(width: 796, height: 392)

    func showTimer() {
        ensureWindow()
        setMode(.timer)
        present()
    }

    func showStats() {
        ensureWindow()
        setMode(.stats)
        present()
    }

    /// Statistics button acts as a toggle back to the clock.
    func toggleStats() {
        setMode(AppState.shared.mode == .stats ? .timer : .stats)
    }

    /// Status item click: hide if visible, otherwise bring the window back.
    func toggleWindow() {
        if let w = timerWindow, w.isVisible {
            w.orderOut(nil)
        } else {
            ensureWindow()
            present()
        }
    }

    private func present() {
        NSApp.activate(ignoringOtherApps: true)
        timerWindow?.makeKeyAndOrderFront(nil)
    }

    private func ensureWindow() {
        guard timerWindow == nil else { return }
        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: timerSize),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        w.title = "Flow"
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.standardWindowButton(.zoomButton)?.isHidden = true
        w.contentView = NSHostingView(rootView: RootView())
        w.backgroundColor = NSColor(Theme.void)
        w.appearance = NSAppearance(named: .darkAqua)
        w.isMovableByWindowBackground = true
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.center()
        timerWindow = w
    }

    private func setMode(_ mode: Mode) {
        AppState.shared.mode = mode
        guard let w = timerWindow else { return }

        let size = mode == .timer ? timerSize : statsSize
        w.contentMinSize = size
        w.contentMaxSize = mode == .timer
            ? size
            : NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        // The clock floats above other apps; the wide stats panel behaves like a normal window.
        w.level = mode == .timer ? .floating : .normal

        let target = clamped(frame(for: size, window: w), on: w)
        guard w.frame != target else { return }
        guard w.isVisible else { w.setFrame(target, display: false); return }

        // setFrame(animate:) runs its animation synchronously and stalls the main
        // thread; the animator proxy does the same move without blocking.
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            w.animator().setFrame(target, display: true)
        }
    }

    private func frameSize(for contentSize: NSSize, window: NSWindow) -> NSSize {
        window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size
    }

    /// Grow and shrink from the window's top-left so the title bar stays put.
    private func frame(for contentSize: NSSize, window: NSWindow) -> NSRect {
        let size = frameSize(for: contentSize, window: window)
        let current = window.frame
        return NSRect(x: current.minX, y: current.maxY - size.height,
                      width: size.width, height: size.height)
    }

    /// Keep the expanded panel on screen when the clock was parked near an edge.
    private func clamped(_ rect: NSRect, on window: NSWindow) -> NSRect {
        guard let vis = (window.screen ?? NSScreen.main)?.visibleFrame else { return rect }
        var r = rect
        r.origin.x = min(max(r.minX, vis.minX), max(vis.minX, vis.maxX - r.width))
        r.origin.y = min(max(r.minY, vis.minY), max(vis.minY, vis.maxY - r.height))
        return r
    }

    // Closing hides the window — the app lives in the menu bar.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
