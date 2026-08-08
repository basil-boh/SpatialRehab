import SwiftUI

/// Trail-making attention/executive-function game: tap 8 scattered, numbered dots in
/// ascending order.
///
/// An out-of-order tap does nothing visible — no shake, no red flash — it's just counted
/// silently for `TrailMakingResult.errorCount`, matching this battery's rule that mistakes
/// are recorded, never shown as "wrong" to the patient. See `Docs/BaselineAssessment_Design.md`.
struct TrailMakingGameView: View {
    let onComplete: (TrailMakingResult) -> Void

    @State private var nextExpectedNumber = 1
    @State private var completedNumbers: Set<Int> = []
    @State private var errorCount = 0
    @State private var startedAt = Date.now

    private let canvasSize = CGSize(width: 640, height: 420)
    private var dotCount: Int { BaselineAssessmentContent.TrailMaking.dotPositions.count }

    var body: some View {
        VStack(spacing: 20) {
            Text("Tap the numbers in order, starting at 1")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.regularMaterial)
                    .frame(width: canvasSize.width, height: canvasSize.height)

                ForEach(Array(BaselineAssessmentContent.TrailMaking.dotPositions.enumerated()), id: \.offset) { index, fraction in
                    dotView(number: index + 1)
                        .position(x: fraction.x * canvasSize.width, y: fraction.y * canvasSize.height)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { startedAt = .now }
    }

    private func dotView(number: Int) -> some View {
        let isDone = completedNumbers.contains(number)
        return Button {
            tap(number)
        } label: {
            Text("\(number)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(isDone ? .white : .primary)
                .frame(width: 52, height: 52)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .tint(isDone ? .green : Color.gray.opacity(0.25))
        .disabled(isDone)
    }

    private func tap(_ number: Int) {
        guard !completedNumbers.contains(number) else { return }

        if number == nextExpectedNumber {
            SoundEffects.playSoftTap()
            completedNumbers.insert(number)
            nextExpectedNumber += 1
            if completedNumbers.count == dotCount {
                finish()
            }
        } else {
            errorCount += 1
        }
    }

    private func finish() {
        onComplete(
            TrailMakingResult(
                dotCount: dotCount,
                errorCount: errorCount,
                durationSeconds: Date.now.timeIntervalSince(startedAt),
                completedAt: .now
            )
        )
    }
}

#Preview(windowStyle: .automatic) {
    TrailMakingGameView(onComplete: { _ in })
}
