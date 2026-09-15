import SwiftUI
import AppKit

/// Terminal-meets-Razer palette. Sharp edges, near-black grounds, one hot accent.
enum Theme {
    static let void        = Color(hex: 0x08090B)   // window ground
    static let panel       = Color(hex: 0x101216)   // raised surface
    static let panelHi     = Color(hex: 0x16191F)   // hover / selected
    static let hairline    = Color(hex: 0x23272F)   // 1px borders

    static let text        = Color(hex: 0xE6E9EF)
    static let textDim     = Color(hex: 0x7C8494)
    static let textFaint   = Color(hex: 0x454B57)

    static let flow        = Color(hex: 0x44D62C)   // razer green
    static let flowBright  = Color(hex: 0x7CFF4F)
    static let rest        = Color(hex: 0x00D4FF)   // break cyan
    static let restBright  = Color(hex: 0x6FE9FF)
    static let danger      = Color(hex: 0xFF3B54)

    /// Heatmap ramp, empty -> maximum focus.
    static let heat: [Color] = [
        Color(hex: 0x14171C),
        Color(hex: 0x16401A),
        Color(hex: 0x1F7A23),
        Color(hex: 0x34B82C),
        Color(hex: 0x62F53F),
    ]

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Uppercase micro-label styling used for every caption in the UI.
    static func label(_ size: CGFloat = 9) -> Font { mono(size, .semibold) }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Thin bordered surface used for every panel in the app.
struct TechPanel: ViewModifier {
    var fill: Color = Theme.panel
    var stroke: Color = Theme.hairline
    func body(content: Content) -> some View {
        content
            .background(fill)
            .overlay(Rectangle().strokeBorder(stroke, lineWidth: 1))
    }
}

extension View {
    func techPanel(fill: Color = Theme.panel, stroke: Color = Theme.hairline) -> some View {
        modifier(TechPanel(fill: fill, stroke: stroke))
    }

    /// Accent glow behind the big numerals and active controls.
    func glow(_ color: Color, radius: CGFloat = 12, opacity: Double = 0.55) -> some View {
        shadow(color: color.opacity(opacity), radius: radius)
    }
}

/// Flat monochrome toolbar button, shared by the timer and statistics headers.
struct IconButton: View {
    let symbol: String
    let help: String
    var action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(hover ? Theme.text : Theme.textDim)
                .frame(width: 26, height: 24)
                .background(hover ? Theme.panelHi : .clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hover = $0 }
    }
}

/// Transparent AppKit strip that makes the area behind it draggable.
struct WindowDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
    }
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
