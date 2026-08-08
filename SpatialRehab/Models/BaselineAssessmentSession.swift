import Foundation

/// Drives the first-launch baseline assessment battery through its fixed phases.
///
/// Deliberately linear and forward-only, same errorless-learning intent as `TaskSession`:
/// no `goBack()` (redoing word-memory recall after seeing the answer would contaminate the
/// trial), and no in-session skip — exiting early is handled one level up by
/// `BaselineAssessmentView`, so this model only ever represents linear forward progress plus
/// whatever results were actually captured.
///
/// Uses `@Observable` rather than `ObservableObject` (unlike `TaskSession`, which predates
/// this repo's move to Observation) — this is new code, so it follows
/// `coding-standards-enforcer`'s current guidance rather than matching older code.
@Observable
@MainActor
final class BaselineAssessmentSession {
    enum Phase: Equatable {
        case intro
        case wordMemory
        case patternMatching
        case arithmetic
        case clockDrawing
        case summary
    }

    private(set) var phase: Phase = .intro
    private(set) var wordMemoryResult: WordMemoryTrial?
    private(set) var patternMatchingResult: PatternMatchingResult?
    private(set) var arithmeticResult: ArithmeticResult?
    private(set) var clockDrawingResult: ClockDrawingResult?

    func begin() {
        guard phase == .intro else { return }
        phase = .wordMemory
    }

    func completeWordMemory(_ result: WordMemoryTrial) {
        guard phase == .wordMemory else { return }
        wordMemoryResult = result
        BaselineResultsStore.save(result)
        phase = .patternMatching
    }

    func completePatternMatching(_ result: PatternMatchingResult) {
        guard phase == .patternMatching else { return }
        patternMatchingResult = result
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
