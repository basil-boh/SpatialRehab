import SwiftUI

/// Home for the repeatable Daily Practice games — separate from the one-time baseline
/// battery (`BaselineAssessmentView`). Each tile shows the game's visible level and a
/// progress bar (never labeled as "difficulty" on screen); day-by-day history lives on its
/// own calendar tab (`PracticeCalendarView`), reachable from the header here. See
/// `Docs/DailyPractice_Design.md`.
///
/// Restyled 2026-08-10 against `DesignSystem.swift`, from the window UI review:
///
/// - **The dot grid is gone.** Progress used to be thirty 6pt dots on 3pt gaps inside a
///   79pt box. At the distance a visionOS window actually sits that is not thirty dots, it
///   is a smudge — nobody can count it, and it was the tile's only progress signal. Six
///   segments carry the same information legibly, and the exact number now lives in the
///   level chip beside it, where it can be read rather than counted.
/// - **Back and calendar are real controls.** "Back" was a plain text button roughly 22pt
///   tall; the calendar was a floating circle in the corner. Both are now 60pt targets in a
///   header row.
/// - **Bilingual titles**, matching the rest of the patient-facing layer.
struct DailyPracticeHubView: View {
    let onExit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var activeGame: PracticeGameKind?
    @State private var progressByKind: [PracticeGameKind: GameProgress] = [:]
    @State private var showingCalendar = false

    /// Flipped on after the tiles land, which drives the progress bars filling from empty.
    /// Progress you can watch arrive reads as progress; a bar that is simply already there
    /// when the screen appears reads as furniture.
    @State private var barsFilled = false

    var body: some View {
        Group {
            if let activeGame {
                PracticeGameContainerView(kind: activeGame) {
                    self.activeGame = nil
                    refreshProgress()
                }
                .transition(.opacity)
            } else {
                hubContent
                    .transition(.opacity)
            }
        }
        .animation(RehabMotion.honouring(reduceMotion), value: activeGame)
        .onAppear {
            refreshProgress()
            fillBars()
        }
        .sheet(isPresented: $showingCalendar, onDismiss: refreshProgress) {
            PracticeCalendarView()
        }
    }

    private var hubContent: some View {
        VStack(spacing: 30) {
            header
                .rehabEntrance(0)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 18)], spacing: 18) {
                ForEach(Array(PracticeGameKind.allCases.enumerated()), id: \.element) { index, kind in
                    gameTile(kind)
                        .rehabEntrance(index + 1)
                }
            }
            .frame(maxWidth: 720)

            Spacer(minLength: 0)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack {
            Button(action: onExit) {
                Label("Back", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .controlSize(.large)

            Spacer(minLength: 12)

            BilingualText(
                english: "Daily Practice",
                chinese: "每日练习",
                font: .rehabTitle,
                alignment: .center
            )

            Spacer(minLength: 12)

            Button {
                showingCalendar = true
            } label: {
                Label("Practice Calendar", systemImage: "calendar")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .controlSize(.large)
        }
        .frame(maxWidth: 720)
    }

    private func gameTile(_ kind: PracticeGameKind) -> some View {
        let progress = progressByKind[kind] ?? GameProgress()
        return Button {
            activeGame = kind
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    Image(systemName: kind.iconName)
                        .font(.system(size: 30))
                        .foregroundStyle(kind.tint)
                        .symbolRenderingMode(.hierarchical)

                    Spacer(minLength: 12)

                    Text(levelLabel(for: kind, progress: progress))
                        .font(.rehabLabel)
                        .foregroundStyle(.secondary)
                        // The level climbs every completed round, so animate the digits
                        // rather than letting them snap on return from a game.
                        .contentTransition(.numericText())
                        .animation(RehabMotion.honouring(reduceMotion, RehabMotion.settle), value: progress.visibleLevel)
                }

                BilingualText(english: kind.title, chinese: chineseTitle(for: kind), font: .rehabBody)

                progressBar(filled: filledSegments(for: kind, progress: progress), tint: kind.tint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        // `.borderless` with a matching border shape, not `.plain`: on visionOS the button's
        // own gaze-hover highlight is shaped by `buttonBorderShape`, and with `.plain` it
        // stayed an oversized rounded rectangle that overshot the tile.
        .buttonStyle(.borderless)
        .buttonBorderShape(.roundedRectangle(radius: RehabMetrics.cardRadius))
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: RehabMetrics.cardRadius, style: .continuous)
        )
    }

    /// Six segments across the tile's width, at a size that survives the viewing distance.
    ///
    /// The precise value stays in the level chip above: precision belongs in the number,
    /// legibility in the bar. Never labeled with the difficulty number on screen — the fill
    /// is the only signal, the same "progress you can see but that never reads as a score"
    /// treatment as everything else in this app.
    private func progressBar(filled: Int, tint: Color) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<Self.segmentCount, id: \.self) { segment in
                Capsule(style: .continuous)
                    .fill(segment < filled ? tint : Color.secondary.opacity(0.22))
                    .frame(height: 9)
                    .scaleEffect(x: barsFilled || segment >= filled ? 1 : 0.001, anchor: .leading)
                    .animation(
                        RehabMotion.honouring(reduceMotion, RehabMotion.settle)?
                            .delay(Double(segment) * 0.05),
                        value: barsFilled
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(filled) of \(Self.segmentCount)")
    }

    private static let segmentCount = 6

    /// How many segments to fill: the adaptive difficulty tier for the three games that
    /// have one, and subjects collected for Draw & Trace, which has no difficulty scale.
    /// Same split the dot grid used, at a sixth of the resolution and many times the
    /// legibility.
    private func filledSegments(for kind: PracticeGameKind, progress: GameProgress) -> Int {
        let levels = PracticeDifficulty.levelRange
        let value = kind.isDifficultyAdaptive ? progress.difficultyLevel : progress.visitedDrawingSubjectIDs.count
        let fraction = Double(value) / Double(levels.count)
        return min(Self.segmentCount, max(0, Int((fraction * Double(Self.segmentCount)).rounded(.up))))
    }

    private func levelLabel(for kind: PracticeGameKind, progress: GameProgress) -> String {
        kind.isDifficultyAdaptive
            ? "Level \(progress.visibleLevel)"
            : "\(progress.visitedDrawingSubjectIDs.count) of \(PracticeDifficulty.levelRange.count)"
    }

    /// The 中文 titles for the four games. Kept here rather than on `PracticeGameKind`
    /// because that enum is shared with the baseline battery's own game views, which are
    /// mid-assessment screens and deliberately monolingual for now.
    private func chineseTitle(for kind: PracticeGameKind) -> String {
        switch kind {
        case .wordMemory: "记词语"
        case .patternMatching: "配对游戏"
        case .arithmetic: "心算"
        case .clockDrawing: "画一画"
        }
    }

    private func refreshProgress() {
        progressByKind = Dictionary(
            uniqueKeysWithValues: PracticeGameKind.allCases.map { ($0, PracticeProgressStore.progress(for: $0)) }
        )
    }

    private func fillBars() {
        guard !barsFilled else { return }
        guard !reduceMotion else {
            barsFilled = true
            return
        }
        // After the tiles themselves have landed, so the two movements read as a sequence
        // rather than one busy moment.
        Task {
            try? await Task.sleep(for: .milliseconds(320))
            barsFilled = true
        }
    }
}

#Preview(windowStyle: .automatic) {
    DailyPracticeHubView(onExit: {})
}
