import SwiftUI

/// Memory-flip pattern-matching game: find all matching pairs of cards.
///
/// Scored by efficiency (see `PatternMatchingResult`), not correctness — a mismatch just
/// flips both cards back after a moment, calmly, with no negative color/sound. This keeps
/// mismatches feeling like "try again," not "wrong," matching errorless-learning intent
/// elsewhere in this battery. See `Docs/BaselineAssessment_Design.md`.
struct PatternMatchingGameView: View {
    let onComplete: (PatternMatchingResult) -> Void

    /// Default reproduces the fixed baseline-battery symbol set exactly, so the existing
    /// call site (`PatternMatchingGameView(onComplete:)`) is unchanged. `DailyPracticeHubView`
    /// passes a tier-scaled symbol subset instead — see `PracticeDifficulty`.
    var symbols: [String] = BaselineAssessmentContent.PatternMatching.symbols

    private struct Card: Identifiable {
        let id = UUID()
        let symbolName: String
        var isFaceUp = false
        var isMatched = false
    }

    @State private var cards: [Card] = []
    @State private var faceUpIndices: [Int] = []
    @State private var moveCount = 0
    @State private var isCheckingMismatch = false

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 16)]

    private var matchedPairCount: Int { cards.filter(\.isMatched).count / 2 }
    private var totalPairCount: Int { cards.count / 2 }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Find the matching pairs")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)

                if totalPairCount > 0 {
                    ProgressView(value: Double(matchedPairCount), total: Double(totalPairCount))
                        .frame(maxWidth: 200)
                }
            }

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    cardView(card, index: index)
                }
            }
            .frame(maxWidth: 640)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: setUpCards)
    }

    private func cardView(_ card: Card, index: Int) -> some View {
        Button {
            flip(index)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(card.isMatched ? Color.green.opacity(0.25) : Color.accentColor.opacity(card.isFaceUp ? 0.18 : 0.9))
                if card.isFaceUp || card.isMatched {
                    Image(systemName: card.symbolName)
                        .font(.system(size: 40))
                        .foregroundStyle(.tint)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 110)
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .disabled(card.isFaceUp || card.isMatched || isCheckingMismatch)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: card.isFaceUp)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: card.isMatched)
    }

    private func setUpCards() {
        guard cards.isEmpty else { return }
        cards = (symbols + symbols).shuffled().map { Card(symbolName: $0) }
    }

    private func flip(_ index: Int) {
        guard !cards[index].isFaceUp, !cards[index].isMatched, faceUpIndices.count < 2 else { return }

        SoundEffects.playTap()
        cards[index].isFaceUp = true
        faceUpIndices.append(index)

        guard faceUpIndices.count == 2 else { return }

        moveCount += 1
        let first = faceUpIndices[0]
        let second = faceUpIndices[1]

        if cards[first].symbolName == cards[second].symbolName {
            cards[first].isMatched = true
            cards[second].isMatched = true
            faceUpIndices = []
            SoundEffects.playSuccess()
            checkForCompletion()
        } else {
            isCheckingMismatch = true
            Task {
                try? await Task.sleep(for: .seconds(0.8))
                cards[first].isFaceUp = false
                cards[second].isFaceUp = false
                faceUpIndices = []
                isCheckingMismatch = false
            }
        }
    }

    private func checkForCompletion() {
        guard cards.allSatisfy(\.isMatched) else { return }
        onComplete(
            PatternMatchingResult(
                pairCount: cards.count / 2,
                moveCount: moveCount,
                completedAt: .now
            )
        )
    }
}

#Preview(windowStyle: .automatic) {
    PatternMatchingGameView(onComplete: { _ in })
}
