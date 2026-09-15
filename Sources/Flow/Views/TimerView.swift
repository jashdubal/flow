import SwiftUI

struct TimerView: View {
    @ObservedObject var engine = TimerEngine.shared
    @ObservedObject var settings = Settings.shared

    private var accent: Color { engine.phase == .flow ? Theme.flow : Theme.rest }
    private var accentBright: Color { engine.phase == .flow ? Theme.flowBright : Theme.restBright }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Spacer(minLength: 0)
            phaseLabel
            clock
            Spacer(minLength: 0)
            dots
            transport
            Spacer(minLength: 0)
            progressRail
        }
        .background(Theme.void)
        .frame(minWidth: 360, minHeight: 212)
    }

    // MARK: header

    private var toolbar: some View {
        HStack(spacing: 2) {
            Spacer()
            IconButton(symbol: "forward.end", help: "Skip phase") { engine.skip() }
            IconButton(symbol: "arrow.counterclockwise", help: "Reset timer") { engine.reset() }
            IconButton(symbol: "square.grid.3x3.fill", help: "Statistics") {
                WindowManager.shared.toggleStats()
            }
            IconButton(symbol: "ellipsis", help: "Menu") { AppMenu.shared.popUpAtCursor() }
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        // Drag anywhere in the header strip to move the window.
        .background(WindowDragArea())
    }

    // MARK: body

    private var phaseLabel: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(accent)
                .frame(width: 5, height: 5)
                .glow(accent, radius: 5, opacity: engine.running ? 0.9 : 0)
            Text(engine.phase.title.uppercased())
                .font(Theme.mono(11, .bold))
                .tracking(3)
                .foregroundColor(Theme.textDim)
        }
    }

    private var clock: some View {
        Text(engine.clockText)
            .font(Theme.mono(56, .light))
            .tracking(-1)
            .foregroundColor(Theme.text)
            .glow(accent, radius: engine.running ? 18 : 6, opacity: engine.running ? 0.45 : 0.15)
            .contentTransition(.numericText())
            .animation(.snappy(duration: 0.18), value: engine.remaining)
            
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(0..<max(1, settings.sessionCount), id: \.self) { i in
                let done = i < engine.completed
                Rectangle()
                    .fill(done ? accent : Theme.textFaint.opacity(0.45))
                    .frame(width: done ? 14 : 6, height: 3)
                    .glow(accent, radius: 4, opacity: done ? 0.7 : 0)
                    .animation(.snappy, value: engine.completed)
            }
        }
        .padding(.bottom, 11)
    }

    private var transport: some View {
        Button(action: { engine.toggle() }) {
            Image(systemName: engine.running ? "pause.fill" : "play.fill")
                .font(.system(size: 15))
                .foregroundColor(accentBright)
                .frame(width: 54, height: 27)
                .background(accent.opacity(engine.running ? 0.16 : 0.08))
                .overlay(Rectangle().strokeBorder(accent.opacity(0.55), lineWidth: 1))
                .glow(accent, radius: 10, opacity: 0.35)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.space, modifiers: [])
    }

    /// Hairline fuel gauge pinned to the bottom edge.
    private var progressRail: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.hairline)
                Rectangle()
                    .fill(LinearGradient(colors: [accent, accentBright],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * engine.progress)
                    .glow(accent, radius: 6, opacity: 0.8)
                    .animation(.linear(duration: 0.25), value: engine.progress)
            }
        }
        .frame(height: 2)
    }
}
