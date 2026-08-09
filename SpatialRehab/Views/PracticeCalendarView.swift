import SwiftUI

/// Day-by-day practice history: a month calendar (green dot on any day something was
/// practiced — the "GitHub contributions" idea, reshaped into a familiar month-grid layout
/// rather than a week-column heatmap, since that's a more immediately readable shape for this
/// audience), a Duolingo-style current-streak counter, and permanent streak badges.
///
/// Deliberately a separate screen from `DailyPracticeHubView`'s tiles (which show
/// difficulty-level dots, not day history) — see `Docs/DailyPractice_Design.md`.
struct PracticeCalendarView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var displayedMonth = Date.now
    @State private var practicedDays: Set<String> = []
    @State private var currentStreak = 0
    @State private var longestStreak = 0

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    streakSummary
                    monthCalendar
                    badgesSection
                    perGameStreaks
                }
                .padding(24)
            }
            .navigationTitle("Your Practice Calendar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        practicedDays = PracticeProgressStore.combinedPracticedDayStrings()
        currentStreak = PracticeProgressStore.currentCombinedStreak()
        longestStreak = PracticeProgressStore.recordCombinedStreakCheckpoint()
    }

    // MARK: - Streak summary

    private var streakSummary: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(currentStreak > 0 ? .orange : .secondary)
                    .symbolRenderingMode(.hierarchical)
                Text("\(currentStreak) day\(currentStreak == 1 ? "" : "s") in a row")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
            }
            Text(currentStreak > 0 ? "Keep it up — come back tomorrow!" : "Practice today to start a streak.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Month calendar

    private var monthCalendar: some View {
        VStack(spacing: 16) {
            HStack {
                Button { changeMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthTitle)
                    .font(.title3.weight(.semibold))

                Spacer()

                Button { changeMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .disabled(isCurrentMonth)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(daysInGrid.enumerated()), id: \.offset) { _, day in
                    dayCell(day)
                }
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func dayCell(_ day: Date?) -> some View {
        Group {
            if let day {
                let practiced = practicedDays.contains(PracticeProgressStore.dayString(for: day))
                let isToday = calendar.isDateInToday(day)

                VStack(spacing: 4) {
                    Text("\(calendar.component(.day, from: day))")
                        .font(.footnote.weight(isToday ? .bold : .regular))
                    Circle()
                        .fill(practiced ? Color.green : Color.clear)
                        .frame(width: 8, height: 8)
                }
                .frame(maxWidth: .infinity, minHeight: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isToday ? Color.accentColor : .clear, lineWidth: 2)
                )
            } else {
                Color.clear.frame(minHeight: 40)
            }
        }
    }

    private func changeMonth(by offset: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) else { return }
        displayedMonth = newMonth
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: .now, toGranularity: .month)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var weekdaySymbols: [String] {
        let symbols = DateFormatter().veryShortWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        let firstIndex = calendar.firstWeekday - 1
        guard symbols.indices.contains(firstIndex) else { return symbols }
        return Array(symbols[firstIndex...] + symbols[..<firstIndex])
    }

    /// One grid cell per day, with leading `nil`s so the 1st of the month lines up under the
    /// correct weekday column.
    private var daysInGrid: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let firstWeekdayOfMonth = calendar.dateComponents([.weekday], from: monthInterval.start).weekday,
              let daysCount = calendar.range(of: .day, in: .month, for: displayedMonth)?.count
        else { return [] }

        let leadingBlanks = (firstWeekdayOfMonth - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for dayOffset in 0..<daysCount {
            cells.append(calendar.date(byAdding: .day, value: dayOffset, to: monthInterval.start))
        }
        return cells
    }

    // MARK: - Badges

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Badges")
                .font(.headline)

            HStack(spacing: 20) {
                badge(milestone: 7, title: "7 Days", icon: "star.fill")
                badge(milestone: 30, title: "30 Days", icon: "trophy.fill")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func badge(milestone: Int, title: String, icon: String) -> some View {
        let earned = longestStreak >= milestone
        return VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(earned ? .yellow : Color.secondary.opacity(0.35))
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(earned ? .primary : .secondary)
        }
        .frame(width: 90)
    }

    // MARK: - Per-game streaks

    /// "Tracking for each style of task," not just one combined number — the calendar and
    /// flame above are the "did you do anything today" view; this is the per-game breakdown.
    private var perGameStreaks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Activity")
                .font(.headline)

            ForEach(PracticeGameKind.allCases) { kind in
                HStack {
                    Image(systemName: kind.iconName)
                        .foregroundStyle(kind.tint)
                    Text(kind.title)
                    Spacer()
                    let streak = PracticeProgressStore.currentStreak(for: kind)
                    Text(streak > 0 ? "\(streak) day\(streak == 1 ? "" : "s")" : "—")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview(windowStyle: .automatic) {
    PracticeCalendarView()
}
