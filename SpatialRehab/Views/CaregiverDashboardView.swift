import SwiftUI
import UIKit

/// Caregiver-facing progress dashboard: trend charts of the baseline battery's history
/// across sessions, plus a clock-drawing gallery.
///
/// This is the polished view meant for a caregiver/family member to actually read.
/// `BaselineResultsDebugView` (reachable via the "Raw Data" toolbar button here) stays the
/// separate, developer-facing raw dump — this view never shows the per-word/per-problem
/// internals that view does, only trends and the clock sketches themselves.
///
/// Depends on `BaselineResultsStore`'s history-array storage (added alongside this view,
/// 2026-08-08) — before that change every game only kept its latest result, so there was
/// nothing to trend. See that file's migration note: pre-existing single-value test data
/// doesn't carry over into the new history arrays, so charts may start empty until a few
/// more sessions are played.
struct CaregiverDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingRawData = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    overviewCard

                    card {
                        ScoreTrendChart(
                            title: "Word Memory",
                            color: .blue,
                            points: BaselineResultsStore.loadWordMemoryHistory().map { TrendPoint(date: $0.completedAt, value: $0.score) }
                        )
                    }
                    card {
                        ScoreTrendChart(
                            title: "Digit Span",
                            color: .pink,
                            points: BaselineResultsStore.loadDigitSpanHistory().map { TrendPoint(date: $0.completedAt, value: $0.score) }
                        )
                    }
                    card {
                        ScoreTrendChart(
                            title: "Pattern Matching",
                            color: .purple,
                            points: BaselineResultsStore.loadPatternMatchingHistory().map { TrendPoint(date: $0.completedAt, value: $0.score) }
                        )
                    }
                    card {
                        ScoreTrendChart(
                            title: "Trail Making",
                            color: .mint,
                            points: BaselineResultsStore.loadTrailMakingHistory().map { TrendPoint(date: $0.completedAt, value: $0.score) }
                        )
                    }
                    card {
                        ScoreTrendChart(
                            title: "Arithmetic",
                            color: .teal,
                            points: BaselineResultsStore.loadArithmeticHistory().map { TrendPoint(date: $0.completedAt, value: $0.score) }
                        )
                    }
                    card {
                        ScoreTrendChart(
                            title: "Orientation",
                            color: .cyan,
                            points: BaselineResultsStore.loadOrientationHistory().map { TrendPoint(date: $0.completedAt, value: $0.score) }
                        )
                    }
                    card {
                        MillisecondTrendChart(
                            title: "Reaction Time",
                            color: .indigo,
                            points: BaselineResultsStore.loadReactionTimeHistory().map { TrendPoint(date: $0.completedAt, value: $0.averageReactionTimeMs) }
                        )
                    }
                    card { clockDrawingGallery }
                }
                .padding(24)
            }
            .navigationTitle("Progress Dashboard")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Raw Data") { showingRawData = true }
                }
            }
            .sheet(isPresented: $showingRawData) {
                BaselineResultsDebugView()
            }
        }
    }

    private var overviewCard: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Overview")
                    .font(.headline)

                let history = BaselineResultsStore.loadWordMemoryHistory()
                if let last = history.last {
                    Text("\(history.count) session\(history.count == 1 ? "" : "s") recorded")
                        .foregroundStyle(.secondary)
                    Text("Last session: \(last.completedAt.formatted(date: .abbreviated, time: .shortened))")
                        .foregroundStyle(.secondary)
                } else {
                    Text("No sessions recorded yet.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var clockDrawingGallery: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Clock Drawings")
                .font(.headline)
            Text("Not automatically scored — review these directly.")
                .font(.caption)
                .foregroundStyle(.secondary)

            let history = BaselineResultsStore.loadClockDrawingHistory()
            if history.isEmpty {
                Text("Not played yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(history, id: \.capturedAt) { result in
                            VStack(spacing: 6) {
                                if let uiImage = UIImage(contentsOfFile: URL.documentsDirectory.appending(path: result.imageFileName).path()) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 120, height: 120)
                                        .background(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                Text(result.capturedAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func card(@ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    CaregiverDashboardView()
}
