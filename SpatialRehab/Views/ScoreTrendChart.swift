import SwiftUI
import Charts

/// One (date, score) reading for a trend chart — a game-agnostic shape so
/// `ScoreTrendChart`/`MillisecondTrendChart` can plot any game's history without knowing
/// its result type.
struct TrendPoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

/// Line-and-point trend chart for a `0...1`-scored game's history across sessions.
///
/// Shared by every scoreable game on `CaregiverDashboardView` — one component, one set of
/// axis/legibility decisions, instead of six near-duplicate charts. `color` is that game's
/// existing identity color, reused from `BaselineResultsDebugView` so the two screens read
/// as the same visual system.
struct ScoreTrendChart: View {
    let title: String
    let color: Color
    let points: [TrendPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            if points.count < 2 {
                Text(points.isEmpty ? "Not played yet." : "Play once more to start a trend.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 120)
            } else {
                Chart(points) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Score", point.value))
                        .foregroundStyle(color)
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", point.date), y: .value("Score", point.value))
                        .foregroundStyle(color)
                }
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(values: [0, 0.5, 1.0]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text("\(Int(doubleValue * 100))%")
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: min(points.count, 4)))
                }
                .frame(height: 120)
            }
        }
    }
}

/// Same idea as `ScoreTrendChart`, for reaction time's raw-millisecond history, which
/// doesn't normalize into a `0...1` score (see `ReactionTimeResult`).
struct MillisecondTrendChart: View {
    let title: String
    let color: Color
    let points: [TrendPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            if points.count < 2 {
                Text(points.isEmpty ? "Not played yet." : "Play once more to start a trend.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 120)
            } else {
                Chart(points) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Reaction time", point.value))
                        .foregroundStyle(color)
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", point.date), y: .value("Reaction time", point.value))
                        .foregroundStyle(color)
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text("\(Int(doubleValue))ms")
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: min(points.count, 4)))
                }
                .frame(height: 120)
            }
        }
    }
}
