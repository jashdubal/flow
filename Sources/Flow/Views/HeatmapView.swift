import SwiftUI

/// What span of days the map is showing.
enum MapRange: Hashable {
    case rolling          // the trailing 52 weeks
    case year(Int)        // one calendar year

    var label: String {
        switch self {
        case .rolling: return "52W"
        case .year(let y): return String(y)
        }
    }
}

/// Focus history as a grid of days, one column per week.
struct HeatmapView: View {
    @ObservedObject var stats = Stats.shared

    private let weeks = 53
    private let cell: CGFloat = 10
    private let gap: CGFloat = 3

    @State private var range: MapRange = .rolling
    @State private var hovered: Day?
    /// Built only when the range or the underlying data changes — rebuilding it on
    /// every body pass (hover included) is what made the panel feel sluggish.
    @State private var grid = Grid.empty

    struct Day: Identifiable, Equatable {
        let date: Date
        let minutes: Int
        var id: Date { date }
    }

    /// One prepared render of the map.
    struct Grid {
        var columns: [[Day?]] = []
        var monthLabels: [String?] = []
        /// Busiest day overall; the colour ramp is scaled against it.
        var peak: Int = 60
        static let empty = Grid()
    }

    // MARK: range -> grid

    /// First day of the leftmost column: the Sunday on or before the span's start.
    private var gridStart: Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let anchor: Date
        switch range {
        case .rolling:
            // Sunday of the current week, then 52 weeks back.
            let sunday = cal.date(byAdding: .day,
                                  value: -(cal.component(.weekday, from: today) - 1),
                                  to: today)!
            return cal.date(byAdding: .day, value: -7 * (weeks - 1), to: sunday)!
        case .year(let y):
            anchor = cal.date(from: DateComponents(year: y, month: 1, day: 1))!
        }
        return cal.date(byAdding: .day,
                        value: -(cal.component(.weekday, from: anchor) - 1),
                        to: anchor)!
    }

    /// Last day the span includes, regardless of today.
    private var spanEnd: Date? {
        guard case .year(let y) = range else { return nil }
        return Calendar.current.date(from: DateComponents(year: y, month: 12, day: 31))!
    }

    /// 53 columns of 7 days. Cells outside the span, or in the future, are blank.
    private func build() -> Grid {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = gridStart
        let end = spanEnd

        let columns: [[Day?]] = (0..<weeks).map { w in
            (0..<7).map { d -> Day? in
                let date = cal.date(byAdding: .day, value: w * 7 + d, to: start)!
                guard date <= today else { return nil }
                if let end, date > end { return nil }
                return Day(date: date, minutes: stats.minutes(on: date))
            }
        }

        let f = DateFormatter(); f.dateFormat = "MMM"
        var lastMonth = -1
        let labels: [String?] = columns.map { col in
            guard let first = col.compactMap({ $0 }).first else { return nil }
            let m = cal.component(.month, from: first.date)
            guard m != lastMonth else { return nil }
            lastMonth = m
            return f.string(from: first.date).uppercased()
        }

        return Grid(columns: columns, monthLabels: labels, peak: max(stats.bestDayMinutes, 60))
    }

    /// Ramp is relative to the best day overall, so years stay comparable.
    private func color(_ minutes: Int) -> Color {
        guard minutes > 0 else { return Theme.heat[0] }
        let ratio = Double(minutes) / Double(grid.peak)
        let idx = min(Theme.heat.count - 1, max(1, Int(ceil(ratio * Double(Theme.heat.count - 1)))))
        return Theme.heat[idx]
    }

    // MARK: layout

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            HStack(alignment: .top, spacing: 6) {
                weekdayGutter
                VStack(alignment: .leading, spacing: 4) {
                    monthRuler
                    gridBody
                }
            }
            legend
        }
        .onAppear { grid = build() }
        .onChange(of: range) { _ in grid = build() }
        .onChange(of: stats.seconds) { _ in grid = build() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("FOCUS MAP")
                .font(Theme.label(10)).tracking(2).foregroundColor(Theme.textDim)
            Text(hovered.map(Self.tooltip) ?? summary)
                .font(Theme.mono(10))
                .foregroundColor(hovered == nil ? Theme.textFaint : Theme.flow)
                .animation(.none, value: hovered)
            Spacer(minLength: 8)
            rangePicker
        }
    }

    /// Total for whatever span is on screen.
    private var summary: String {
        let minutes: Int
        switch range {
        case .rolling: minutes = stats.minutes(lastDays: 371)
        case .year(let y): minutes = stats.minutes(inYear: y)
        }
        return "\(range == .rolling ? "TRAILING YEAR" : range.label) · \(StatsView.hm(minutes))"
    }

    private var rangePicker: some View {
        HStack(spacing: 4) {
            chip(.rolling)
            ForEach(stats.years, id: \.self) { chip(.year($0)) }
        }
    }

    private func chip(_ value: MapRange) -> some View {
        let on = range == value
        return Button { range = value } label: {
            Text(value.label)
                .font(Theme.mono(9, .semibold))
                .tracking(1)
                .foregroundColor(on ? Theme.flowBright : Theme.textDim)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(on ? Theme.flow.opacity(0.16) : Color.clear)
                .overlay(Rectangle().strokeBorder(
                    on ? Theme.flow.opacity(0.7) : Theme.hairline, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private static func tooltip(_ day: Day) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM yyyy"
        let amount = day.minutes == 0
            ? "no focus"
            : (day.minutes >= 60
                ? String(format: "%dh %02dm", day.minutes / 60, day.minutes % 60)
                : "\(day.minutes)m")
        return "\(f.string(from: day.date).uppercased())  ·  \(amount)"
    }

    private var weekdayGutter: some View {
        VStack(alignment: .trailing, spacing: gap) {
            Color.clear.frame(height: 11) // aligns with the month ruler
            ForEach(Array(["", "MON", "", "WED", "", "FRI", ""].enumerated()), id: \.offset) { _, s in
                Text(s)
                    .font(Theme.mono(8))
                    .foregroundColor(Theme.textFaint)
                    .fixedSize()
                    .frame(width: 26, height: cell, alignment: .trailing)
            }
        }
        .padding(.top, 4)
    }

    private var monthRuler: some View {
        let labels = grid.monthLabels
        return HStack(spacing: gap) {
            ForEach(grid.columns.indices, id: \.self) { i in
                // Labels are drawn in an overlay so a 3-letter month may overhang
                // its narrow column instead of wrapping.
                Color.clear
                    .frame(width: cell, height: 11)
                    .overlay(alignment: .leading) {
                        if let m = labels.indices.contains(i) ? labels[i] : nil {
                            Text(m)
                                .font(Theme.mono(8))
                                .foregroundColor(Theme.textFaint)
                                .fixedSize()
                        }
                    }
            }
        }
        .frame(height: 11, alignment: .bottom)
    }

    private var gridSize: CGSize {
        CGSize(width: CGFloat(weeks) * cell + CGFloat(weeks - 1) * gap,
               height: 7 * cell + 6 * gap)
    }

    /// The whole map is one Canvas pass. As 371 separate views it cost ~60ms to
    /// build, which is what made opening statistics stutter.
    private var gridBody: some View {
        Canvas(rendersAsynchronously: false) { ctx, _ in
            for (c, col) in grid.columns.enumerated() {
                for (r, day) in col.enumerated() {
                    guard let day else { continue }
                    let rect = cellRect(col: c, row: r)
                    ctx.fill(Path(rect), with: .color(color(day.minutes)))
                    if day.minutes > 0 {
                        ctx.stroke(Path(rect.insetBy(dx: 0.5, dy: 0.5)),
                                   with: .color(Theme.flow.opacity(0.3)), lineWidth: 1)
                    }
                    if hovered == day {
                        ctx.stroke(Path(rect.insetBy(dx: 0.5, dy: 0.5)),
                                   with: .color(Theme.text), lineWidth: 1)
                    }
                }
            }
        }
        .frame(width: gridSize.width, height: gridSize.height)
        .onContinuousHover(coordinateSpace: .local) { phase in
            switch phase {
            case .active(let p): hovered = day(at: p)
            case .ended: hovered = nil
            }
        }
    }

    private func cellRect(col: Int, row: Int) -> CGRect {
        CGRect(x: CGFloat(col) * (cell + gap), y: CGFloat(row) * (cell + gap),
               width: cell, height: cell)
    }

    /// Maps a pointer position back to a day, ignoring the gaps between cells.
    private func day(at p: CGPoint) -> Day? {
        let stride = cell + gap
        let col = Int(p.x / stride), row = Int(p.y / stride)
        guard col >= 0, col < grid.columns.count, row >= 0, row < 7 else { return nil }
        guard p.x - CGFloat(col) * stride <= cell,
              p.y - CGFloat(row) * stride <= cell else { return nil }
        return grid.columns[col][row]
    }

    private var legend: some View {
        HStack(spacing: gap) {
            Text("LESS").font(Theme.mono(8)).foregroundColor(Theme.textFaint)
            ForEach(Array(Theme.heat.enumerated()), id: \.offset) { _, c in
                Rectangle().fill(c).frame(width: cell, height: cell)
            }
            Text("MORE").font(Theme.mono(8)).foregroundColor(Theme.textFaint)
        }
    }
}
