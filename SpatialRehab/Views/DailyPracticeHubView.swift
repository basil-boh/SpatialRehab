import SwiftUI

/// Home for the repeatable Daily Practice games — separate from the one-time baseline
/// battery (`BaselineAssessmentView`). Each tile shows the game's visible level and a
/// difficulty-level dot grid (1–30, never labeled as "difficulty" on screen); day-by-day
/// history lives on its own calendar tab (`PracticeCalendarView`), reachable from the corner
/// button here. See `Docs/DailyPractice_Design.md`.
struct DailyPracticeHubView: View {
    let onExit: () -> Void

    @State private var activeGame: PracticeGameKind?
    @State private var progressByKind: [PracticeGameKind: GameProgress] = [:]
    @State private var showingCalendar = false

    /// Retaking the baseline quiz from here is optional and repeatable, unlike
    /// `SpatialRehabApp`'s mandatory first-launch gate — a fresh `BaselineAssessmentSession`
    /// per presentation so it always starts at `.intro`, never resuming a previous attempt
    /// (the session type has no `reset()`/`goBack()` by design — see its doc comment — so a
    /// new instance is the correct way to restart it).
    @State private var showingBaselineQuiz = false
    @State private var baselineQuizSession = BaselineAssessmentSession()

    var body: some View {
        Group {
            if let activeGame {
                PracticeGameContainerView(kind: activeGame) {
                    self.activeGame = nil
                    refreshProgress()
                }
            } else {
                hubContent
            }
        }
        .onAppear(perform: refreshProgress)
        .sheet(isPresented: $showingCalendar, onDismiss: refreshProgress) {
            PracticeCalendarView()
        }
        .sheet(isPresented: $showingBaselineQuiz, onDismiss: { baselineQuizSession = BaselineAssessmentSession() }) {
            BaselineAssessmentView(session: baselineQuizSession) {
                showingBaselineQuiz = false
            }
        }
    }

    private var hubContent: some View {
        ZStack {
            VStack(spacing: 32) {
                Text("Daily Practice")
                    .font(.system(size: 40, weight: .semibold, design: .rounded))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 20)], spacing: 20) {
                    ForEach(PracticeGameKind.allCases) { kind in
                        gameTile(kind)
                    }
                }
                .frame(maxWidth: 700)

                Button("Back", action: onExit)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                showingBaselineQuiz = true
            } label: {
                Label("Baseline Quiz", systemImage: "checklist")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Button {
                showingCalendar = true
            } label: {
                Image(systemName: "calendar")
                    .font(.title2)
                    .padding(14)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }

    private func gameTile(_ kind: PracticeGameKind) -> some View {
        let progress = progressByKind[kind] ?? GameProgress()
        return Button {
            activeGame = kind
        } label: {
            VStack(spacing: 12) {
                Image(systemName: kind.iconName)
                    .font(.system(size: 36))
                    .foregroundStyle(kind.tint)
                    .symbolRenderingMode(.hierarchical)

                Text(kind.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Level \(progress.visibleLevel)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Every tile gets a 30-dot grid now — the three difficulty-adaptive games
                // show difficulty progress; Draw & Trace (no difficulty scale) shows how many
                // of its 30 subjects have been collected instead, so no tile is left with no
                // visual progress indicator at all.
                if kind.isDifficultyAdaptive {
                    dotGrid(filledCount: progress.difficultyLevel, tint: kind.tint)
                } else {
                    dotGrid(filledCount: progress.visitedDrawingSubjectIDs.count, tint: kind.tint)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// Compact grid (10 columns) of `PracticeDifficulty.levelRange.count` (30) dots, the
    /// first `filledCount` shown filled. Never labeled with a number on screen — the fill
    /// amount is the only signal, same "progress you can see but that never reads as a
    /// score" treatment as everything else in this app.
    private func dotGrid(filledCount: Int, tint: Color) -> some View {
        let allLevels = Array(PracticeDifficulty.levelRange)
        let columns = Array(repeating: GridItem(.fixed(7), spacing: 3), count: 10)
        return LazyVGrid(columns: columns, spacing: 3) {
            ForEach(allLevels, id: \.self) { dotLevel in
                Circle()
                    .fill(dotLevel <= filledCount ? tint : Color.secondary.opacity(0.2))
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 79)
    }

    private func refreshProgress() {
        progressByKind = Dictionary(
            uniqueKeysWithValues: PracticeGameKind.allCases.map { ($0, PracticeProgressStore.progress(for: $0)) }
        )
    }
}

#Preview(windowStyle: .automatic) {
    DailyPracticeHubView(onExit: {})
}
