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
struct BaselineResultsDebugView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                wordMemorySection
                patternMatchingSection
                arithmeticSection
                clockDrawingSection
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
