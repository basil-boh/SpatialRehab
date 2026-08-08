import Foundation

/// Drives the first-launch baseline assessment battery through its fixed phases.
///
/// Deliberately linear and forward-only, same errorless-learning intent as `TaskSession`:
/// no `goBack()` (redoing a memory trial after seeing the answer would contaminate it), and
/// no in-session skip — exiting early is handled one level up by `BaselineAssessmentView`,
/// so this model only ever represents linear forward progress plus whatever results were
/// actually captured.
///
/// Battery order groups related domains together (memory games adjacent, executive-function
/// games adjacent) rather than an arbitrary sequence, and opens with `reactionTime` as a
/// literal warm-up (matching the "Touch the dots" hand-eye-coordination warm-up from the
/// product-vision doc) and closes with the free-form `clockDrawing`. See
/// `Docs/BaselineAssessment_Design.md`.
///
/// Uses `@Observable` rather than `ObservableObject` (unlike `TaskSession`, which predates
/// this repo's move to Observation) — this is new code, so it follows
/// `coding-standards-enforcer`'s current guidance rather than matching older code.
@Observable
@MainActor
final class BaselineAssessmentSession {
    enum Phase: Equatable, CaseIterable {
        case intro
        case reactionTime
        case orientation
        case wordMemory
        case digitSpan
        case patternMatching
        case trailMaking
        case arithmetic
        case clockDrawing
        case summary

        /// Excludes `intro`/`summary` — used wherever UI needs "how many games total"
        /// (e.g. `ContentView`'s completed-activities stat) without hardcoding the count.
        static var gameCount: Int { allCases.count - 2 }
    }

    private(set) var phase: Phase = .intro
    private(set) var reactionTimeResult: ReactionTimeResult?
    private(set) var orientationResult: OrientationResult?
    private(set) var wordMemoryResult: WordMemoryTrial?
    private(set) var digitSpanResult: DigitSpanResult?
    private(set) var patternMatchingResult: PatternMatchingResult?
    private(set) var trailMakingResult: TrailMakingResult?
    private(set) var arithmeticResult: ArithmeticResult?
    private(set) var clockDrawingResult: ClockDrawingResult?

    func begin() {
        guard phase == .intro else { return }
        phase = .reactionTime
    }

    func completeReactionTime(_ result: ReactionTimeResult) {
        guard phase == .reactionTime else { return }
        reactionTimeResult = result
        BaselineResultsStore.save(result)
        phase = .orientation
    }

    func completeOrientation(_ result: OrientationResult) {
        guard phase == .orientation else { return }
        orientationResult = result
        BaselineResultsStore.save(result)
        phase = .wordMemory
    }

    func completeWordMemory(_ result: WordMemoryTrial) {
        guard phase == .wordMemory else { return }
        wordMemoryResult = result
        BaselineResultsStore.save(result)
        phase = .digitSpan
    }

    func completeDigitSpan(_ result: DigitSpanResult) {
        guard phase == .digitSpan else { return }
        digitSpanResult = result
        BaselineResultsStore.save(result)
        phase = .patternMatching
    }

    func completePatternMatching(_ result: PatternMatchingResult) {
        guard phase == .patternMatching else { return }
        patternMatchingResult = result
        BaselineResultsStore.save(result)
        phase = .trailMaking
    }

    func completeTrailMaking(_ result: TrailMakingResult) {
        guard phase == .trailMaking else { return }
        trailMakingResult = result
        BaselineResultsStore.save(result)
        phase = .arithmetic
    }

    func completeArithmetic(_ result: ArithmeticResult) {
        guard phase == .arithmetic else { return }
        arithmeticResult = result
        BaselineResultsStore.save(result)
        phase = .clockDrawing
    }

    func completeClockDrawing(_ result: ClockDrawingResult) {
        guard phase == .clockDrawing else { return }
        clockDrawingResult = result
        BaselineResultsStore.save(result)
        phase = .summary
    }
}
