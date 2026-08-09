import SwiftUI

/// Wraps one of the four game views for a Daily Practice round: builds this round's
/// tier-scaled content, hosts the game, and on completion records progress (level bump +
/// adaptive tier + today's practice mark — see `PracticeProgressStore`) before showing a
/// brief, purely positive completion screen. See `Docs/DailyPractice_Design.md`.
struct PracticeGameContainerView: View {
    let kind: PracticeGameKind
    let onExit: () -> Void

    @State private var progress: GameProgress
    @State private var isComplete = false

    // Generated once in `init`, not recomputed on every body evaluation — otherwise content
    // would reshuffle mid-round any time unrelated state changes trigger a re-render.
    @State private var wordRound: (targets: [String], distractors: [String])
    @State private var patternSymbols: [String]
    @State private var arithmeticProblems: [BaselineAssessmentContent.Arithmetic.Problem]

    init(kind: PracticeGameKind, onExit: @escaping () -> Void) {
        self.kind = kind
        self.onExit = onExit
        let startingProgress = PracticeProgressStore.progress(for: kind)
        _progress = State(initialValue: startingProgress)
        _wordRound = State(initialValue: PracticeDifficulty.WordMemory.makeRound(level: startingProgress.difficultyLevel))
        _patternSymbols = State(initialValue: PracticeDifficulty.PatternMatching.makeRoundSymbols(level: startingProgress.difficultyLevel))
        _arithmeticProblems = State(initialValue: PracticeDifficulty.Arithmetic.makeProblems(level: startingProgress.difficultyLevel))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if isComplete {
                completionContent
            } else {
                gameContent
            }

            Button("Exit", action: onExit)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.footnote)
                .padding()
        }
    }

    @ViewBuilder
    private var gameContent: some View {
        switch kind {
        case .wordMemory:
            WordMemoryGameView(
                onComplete: { finish(score: $0.score) },
                targetWords: wordRound.targets,
                distractorWords: wordRound.distractors,
                studyDurationSeconds: PracticeDifficulty.WordMemory.studyDurationSeconds(forLevel: progress.difficultyLevel)
            )
        case .patternMatching:
            PatternMatchingGameView(onComplete: { finish(score: $0.score) }, symbols: patternSymbols)
        case .arithmetic:
            ArithmeticGameView(onComplete: { finish(score: $0.score) }, problems: arithmeticProblems)
        case .clockDrawing:
            // No score to adapt from — see PracticeGameKind.isDifficultyAdaptive. The
            // subject still cycles with visibleLevel: clock at level 1, then a different
            // traceable animal/object each level after — see DrawingSubjects.
            let subject = currentDrawingSubject
            ClockDrawingView(
                onComplete: { _ in finish(score: nil, visitedDrawingSubjectID: subject.id) },
                subject: subject,
                outlineOpacity: DrawingSubjects.outlineOpacity(forLevel: progress.visibleLevel)
            )
        }
    }

    private var currentDrawingSubject: DrawingSubject {
        DrawingSubjects.subject(forLevel: progress.visibleLevel)
    }

    private var completionContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
                .symbolRenderingMode(.hierarchical)

            Text("Nice work!")
                .font(.system(size: 30, weight: .semibold, design: .rounded))

            Text("Level \(progress.visibleLevel)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)

            Button("Back to Practice", action: onExit)
                .font(.title3.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func finish(score: Double?, visitedDrawingSubjectID: String? = nil) {
        progress = PracticeProgressStore.recordCompletion(
            for: kind,
            score: score,
            visitedDrawingSubjectID: visitedDrawingSubjectID
        )
        SoundEffects.playSuccess()
        isComplete = true
    }
}

#Preview(windowStyle: .automatic) {
    PracticeGameContainerView(kind: .arithmetic, onExit: {})
}
