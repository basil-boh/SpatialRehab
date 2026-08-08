import SwiftUI
import UIKit

/// Development-only screen that surfaces the raw data the baseline battery captured, so
/// scoring/capture logic can be verified without leaving the app. Not part of the
/// patient-facing flow — reached via a dev button on the post-baseline welcome screen
/// (`ContentView`). Reads directly from `BaselineResultsStore` (persisted after each game
/// completes) rather than a live session reference, so it reflects whatever was captured
/// even if the battery was exited early.
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
                row("Target words", result.targetWords.joined(separator: ", "))
                row("Tapped words", result.tappedWords.sorted().joined(separator: ", "))
                row("Correct", "\(result.correctlyRecognized.count) of \(result.targetWords.count)")
                row("False positives", "\(result.falsePositives.count)")
                row("Score", percent(result.score))
            } else {
                notCompletedRow
            }
        }
    }

    @ViewBuilder
    private var patternMatchingSection: some View {
        Section("Pattern Matching") {
            if let result = BaselineResultsStore.loadPatternMatchingResult() {
                row("Pairs", "\(result.pairCount)")
                row("Moves", "\(result.moveCount)")
                row("Efficiency score", percent(result.score))
            } else {
                notCompletedRow
            }
        }
    }

    @ViewBuilder
    private var arithmeticSection: some View {
        Section("Arithmetic") {
            if let result = BaselineResultsStore.loadArithmeticResult() {
                ForEach(Array(result.answers.enumerated()), id: \.offset) { _, answer in
                    row(answer.promptText, "\(answer.selectedAnswer) — \(answer.isCorrect ? "correct" : "incorrect")")
                }
                row("Score", percent(result.score))
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
                row("Score", result.score.map(String.init) ?? "Not scored (by design — see Docs)")
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

    private func percent(_ score: Double) -> String {
        "\(Int((score * 100).rounded()))%"
    }
}

#Preview {
    BaselineResultsDebugView()
}
