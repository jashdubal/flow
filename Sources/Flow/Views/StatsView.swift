import SwiftUI

struct StatsView: View {
    @ObservedObject var stats = Stats.shared
    @State private var confirmingReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            title
            tiles
            HeatmapView()
                .padding(14)
                .techPanel()
            Spacer(minLength: 0)
            footer
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        // Clears the transparent title bar and its traffic lights.
        .padding(.top, 28)
        .frame(minWidth: 796, minHeight: 392)
        .background(Theme.void)
    }

    private var title: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("▚ FLOW")
                .font(Theme.mono(14, .bold)).foregroundColor(Theme.flow)
                .glow(Theme.flow, radius: 8, opacity: 0.5)
            Text("/ STATISTICS")
                .font(Theme.mono(14, .regular)).foregroundColor(Theme.textDim)
            Spacer()
            IconButton(symbol: "chevron.left", help: "Back to timer") {
                WindowManager.shared.toggleStats()
            }
        }
    }

    private var tiles: some View {
        HStack(spacing: 10) {
            Tile(label: "TODAY", value: Self.hm(stats.todayMinutes), accent: Theme.flow)
            Tile(label: "THIS WEEK", value: Self.hm(stats.minutes(lastDays: 7)), accent: Theme.flow)
            Tile(label: "STREAK", value: "\(stats.streak)", unit: stats.streak == 1 ? "DAY" : "DAYS", accent: Theme.rest)
            Tile(label: "SESSIONS", value: "\(stats.totalSessions)", accent: Theme.rest)
            Tile(label: "ALL TIME", value: Self.hm(stats.totalMinutes), accent: Theme.textDim)
        }
    }

    private var footer: some View {
        HStack {
            Text("~/Library/Application Support/Flow/stats.json")
                .font(Theme.mono(9)).foregroundColor(Theme.textFaint)
            Spacer()
            Button(confirmingReset ? "CONFIRM WIPE" : "RESET DATA") {
                if confirmingReset { stats.reset(); confirmingReset = false }
                else {
                    confirmingReset = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) { confirmingReset = false }
                }
            }
            .buttonStyle(GhostButton(accent: confirmingReset ? Theme.danger : Theme.textDim))
        }
    }

    static func hm(_ minutes: Int) -> String {
        minutes >= 60 ? String(format: "%dh %02dm", minutes / 60, minutes % 60) : "\(minutes)m"
    }
}

private struct Tile: View {
    let label: String
    let value: String
    var unit: String? = nil
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(Theme.label(9)).tracking(1.5).foregroundColor(Theme.textDim)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(Theme.mono(20, .medium))
                    .foregroundColor(Theme.text)
                if let unit {
                    Text(unit).font(Theme.mono(9)).foregroundColor(Theme.textFaint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .techPanel()
        .overlay(alignment: .top) {
            Rectangle().fill(accent).frame(height: 2).glow(accent, radius: 5, opacity: 0.7)
        }
    }
}

struct GhostButton: ButtonStyle {
    var accent: Color
    @State private var hover = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.label(9)).tracking(1.5)
            .foregroundColor(hover ? Theme.text : accent)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(hover ? accent.opacity(0.14) : .clear)
            .overlay(Rectangle().strokeBorder(accent.opacity(0.6), lineWidth: 1))
            .onHover { hover = $0 }
    }
}
