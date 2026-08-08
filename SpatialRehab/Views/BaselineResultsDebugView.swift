import SwiftUI
import Charts
import UIKit

/// Development-only screen that surfaces the raw data the baseline battery captured, so
/// scoring/capture logic can be verified without leaving the app. Not part of the
/// patient-facing flow — reached via a dev button on the post-baseline welcome screen
/// (`ContentView`). Reads directly from `BaselineResultsStore` (persisted after each game
/// completes) rather than a live session reference, so it reflects whatever was captured
/// even if the battery was exited early.
///
/// Color use here is deliberately status-based, not decorative: green/gray/amber always mean
/// correct/missed/flagged, reused identically across every game's breakdown chart; each
/// game gets one fixed identity hue (blue/purple/teal) for its gauge, never cycled or reused
/// for a different meaning. This is a dev-only screen so palette choices weren't run through
/// a formal colorblind-safety validator (see `.skills` dataviz guidance) — worth doing if
/// this ever becomes a caregiver-facing surface.
///
/// The final section surfaces `GameRecommendationEngine`'s output (weakest-domain-first
/// game suggestions). Deliberately kept here rather than shown to the patient: the
/// suggested games (`StimulationGameCatalog`) don't have real screens built yet, so
/// recommending one to the patient would point at something that isn't tappable — fine
/// for a developer/caregiver to preview, not fine to promise a person with dementia.
struct BaselineResultsDebugView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                reactionTimeSection
                orientationSection
                wordMemorySection
                digitSpanSection
                patternMatchingSection
                trailMakingSection
                arithmeticSection
                clockDrawingSection
                recommendationSection
            }
            .navigationTitle("Baseline Data (Dev)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var reactionTimeSection: some View {
        Section("Reaction Time") {
            if let result = BaselineResultsStore.loadReactionTimeResult() {
                row("Average", "\(Int(result.averageReactionTimeMs.rounded())) ms")
                BreakdownChart(items: result.reactionTimesMs.enumerated().map { index, ms in
                    BreakdownItem(label: "Trial \(index + 1)", count: Int(ms.rounded()), color: .indigo)
                })
                .padding(.vertical, 6)
            } else {
                notCompletedRow
            }
        }
    }

    @ViewBuilder
    private var orientationSection: some View {
        Section("Orientation") {
            if let result = BaselineResultsStore.loadOrientationResult() {
                HStack(alignment: .top, spacing: 20) {
                    ScoreGauge(score: result.score, tint: .cyan)
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(result.answers.enumerated()), id: \.offset) { _, answer in
                            HStack(spacing: 8) {
                                Image(systemName: answer.isCorrect ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(answer.isCorrect ? .green : .secondary)
                                Text(answer.promptText)
                                Spacer()
                                Text(answer.selectedAnswer)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            } else {
                notCompletedRow
            }
        }
    }

    @ViewBuilder
    private var digitSpanSection: some View {
        Section("Digit Span") {
            if let result = BaselineResultsStore.loadDigitSpanResult() {
                HStack(alignment: .top, spacing: 20) {
                    ScoreGauge(score: result.score, tint: .pink)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Target: \(result.targetSequence.map(String.init).joined(separator: " "))")
                        Text("Entered: \(result.enteredSequence.map(String.init).joined(separator: " "))")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            } else {
                notCompletedRow
            }
        }
    }

    @ViewBuilder
    private var trailMakingSection: some View {
        Section("Trail Making") {
            if let result = BaselineResultsStore.loadTrailMakingResult() {
                HStack(spacing: 20) {
                    ScoreGauge(score: result.score, tint: .mint)
                    BreakdownChart(items: [
                        BreakdownItem(label: "Dots", count: result.dotCount, color: .mint),
                        BreakdownItem(label: "Errors", count: result.errorCount, color: .orange),
                    ])
                }
                .padding(.vertical, 6)
                row("Duration", "\(Int(result.durationSeconds.rounded())) s")
            } else {
                notCompletedRow
            }
        }
    }

    @ViewBuilder
    private var wordMemorySection: some View {
        Section("Word Memory") {
            if let result = BaselineResultsStore.loadWordMemoryResult() {
                HStack(spacing: 20) {
                    ScoreGauge(score: result.score, tint: .blue)
                    BreakdownChart(items: [
                        BreakdownItem(label: "Correct", count: result.correctlyRecognized.count, color: .green),
                        BreakdownItem(label: "Missed", count: result.targetWords.count - result.correctlyRecognized.count, color: .gray),
                        BreakdownItem(label: "Extra taps", count: result.falsePositives.count, color: .orange),
                    ])
                }
                .padding(.vertical, 6)
                row("Target words", result.targetWords.joined(separator: ", "))
                row("Tapped words", result.tappedWords.sorted().joined(separator: ", "))
            } else {
                notCompletedRow
            }
        }
    }

    @ViewBuilder
    private var patternMatchingSection: some View {
        Section("Pattern Matching") {
            if let result = BaselineResultsStore.loadPatternMatchingResult() {
                HStack(spacing: 20) {
                    ScoreGauge(score: result.score, tint: .purple)
                    BreakdownChart(items: [
                        BreakdownItem(label: "Ideal moves", count: result.pairCount, color: .purple.opacity(0.35)),
                        BreakdownItem(label: "Actual moves", count: result.moveCount, color: .purple),
                    ])
                }
                .padding(.vertical, 6)
            } else {
                notCompletedRow
            }
        }
    }

    @ViewBuilder
    private var arithmeticSection: some View {
        Section("Arithmetic") {
            if let result = BaselineResultsStore.loadArithmeticResult() {
                HStack(alignment: .top, spacing: 20) {
                    ScoreGauge(score: result.score, tint: .teal)
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(result.answers.enumerated()), id: \.offset) { _, answer in
                            HStack(spacing: 8) {
                                Image(systemName: answer.isCorrect ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(answer.isCorrect ? .green : .secondary)
                                Text(answer.promptText)
                                Spacer()
                                Text("\(answer.selectedAnswer)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            } else {
                notCompletedRow
            }
        }
    }

    @ViewBuilder
    private var clockDrawingSection: some View {
        Section("Clock Drawing") {
            if let result = BaselineResultsStore.loadClockDrawingResult() {
                row("Captured at", result.capturedAt.formatted(date: .abbreviated, time: .shortened))
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundStyle(.gray)
                    Text(result.score.map(String.init) ?? "Not scored (by design — see Docs)")
                        .foregroundStyle(.secondary)
                }
                if let uiImage = UIImage(contentsOfFile: URL.documentsDirectory.appending(path: result.imageFileName).path()) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            } else {
                notCompletedRow
            }
        }
    }

    @ViewBuilder
    private var recommendationSection: some View {
        Section("Recommended Focus (Dev)") {
            let recommendations = GameRecommendationEngine.currentRecommendations()
            if recommendations.isEmpty {
                notCompletedRow
            } else {
                BreakdownChart(items: recommendations.map {
                    BreakdownItem(
                        label: $0.domain.displayName,
                        count: Int(($0.priority * 100).rounded()),
                        color: domainColor($0.domain)
                    )
                })
                .padding(.vertical, 6)

                if let top = recommendations.first {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Top priority: \(top.domain.displayName)")
                            .font(.subheadline.weight(.semibold))
                        ForEach(top.games) { game in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(game.title)
                                    .font(.callout.weight(.medium))
                                Text(game.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    /// Reuses each domain's home game's identity color (word memory=blue,
    /// arithmetic=teal, pattern matching=purple) so this section reads as the same
    /// visual language as the score gauges above, not a fourth unrelated palette.
    private func domainColor(_ domain: CognitiveDomain) -> Color {
        switch domain {
        case .memory: .blue
        case .numeracy: .teal
        case .executiveFunction: .purple
        }
    }

    private var notCompletedRow: some View {
        Text("Not completed yet")
            .foregroundStyle(.secondary)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

/// Circular percentage gauge for one game's score. `tint` is that game's fixed identity
/// color — never reused for a different game or a different meaning.
private struct ScoreGauge: View {
    let score: Double
    let tint: Color

    var body: some View {
        Gauge(value: score, in: 0...1) {
            EmptyView()
        } currentValueLabel: {
            Text("\(Int((score * 100).rounded()))%")
                .font(.headline)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(tint)
        .frame(width: 64, height: 64)
    }
}

private struct BreakdownItem: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
    let color: Color
}

/// Minimal horizontal bar chart: no axis (recessive), direct count labels instead.
private struct BreakdownChart: View {
    let items: [BreakdownItem]

    var body: some View {
        Chart(items) { item in
            BarMark(
                x: .value("Count", item.count),
                y: .value("Label", item.label)
            )
            .foregroundStyle(item.color)
            .cornerRadius(4)
            .annotation(position: .trailing) {
                Text("\(item.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .chartXAxis(.hidden)
        .frame(height: CGFloat(items.count) * 26 + 8)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    BaselineResultsDebugView()
}
