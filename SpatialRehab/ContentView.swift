import SwiftUI

/// The main window's three patient-facing screens: the home screen (reached once
/// `SpatialRehabApp.hasCompletedBaseline` flips to true), the guidance panel shown while a
/// kopi or mahjong activity runs, and the finished screen.
///
/// Reconciled 2026-08-08, three times: first when both branches had independently rewritten
/// `ContentView` as the app's home screen (this branch's activity picker vs.
/// baseline-metrics' caregiver check-in card — Basil chose the activity picker), then again
/// after a teammate's follow-up commit simplified the picker down to a single activity
/// (Touch the Dots / Walk to the Bakery / Find Your Way Home were removed), then again after
/// baseline-metrics grew a Daily Practice hub and replaced its own home screen with a
/// greeting card — folded in here as a secondary "Daily Practice" entry point rather than
/// adopting the greeting-card layout.
///
/// **Re-ranked 2026-08-10 (Basil):** Daily Practice is the thing a person is actually here
/// to do most days, and it was the smallest button on the screen. It is now the featured
/// card. Below it sits Remember the Way — the one immersive exercise that is a
/// rehabilitation task rather than a game — then kopi and mahjong together under "Games",
/// then the caregiver dashboard, which is not for the person wearing the device at all.
/// That ranking is fixed, not adaptive: a predictable layout is worth more to someone with
/// dementia than variety is.
///
/// **Restyled 2026-08-10** against `DesignSystem.swift`, from the window UI review:
///
/// - **Orientation for free.** The header states the day, date and time of day, and greets
///   her by name. The baseline battery ships an *orientation* mini-game precisely because
///   that is what slips first; the screen she sees every session should not withhold it.
/// - **Bilingual throughout**, matching the persona layer. See `BilingualText`.
/// - **No tally on the finished screen.** It used to close with "N of 8 activities
///   completed", which on a screen whose whole job is unconditional affirmation reads as a
///   report card — the exact thing `BaselineAssessmentView` refuses to show. Counting is a
///   caregiver concern and stays in `CaregiverDashboardView`.
/// - **The guidance panel has controls.** It used to be two static lines and no way out.
struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showingDashboard = false
    @State private var showingDailyPractice = false

    /// Re-read whenever the home screen comes back into view, rather than computed inline,
    /// so the greeting and date can't go stale in a window left open across a session.
    @State private var now = Date.now

    /// Whether the current step's hint has been asked for. Reset on every step change, so
    /// "Show me" is a fresh offer each time rather than a permanent spoiler.
    @State private var hintShown = false

    var body: some View {
        Group {
            if showingDailyPractice {
                DailyPracticeHubView(onExit: { showingDailyPractice = false })
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                screens
                    .transition(.opacity)
            }
        }
        .animation(RehabMotion.honouring(reduceMotion), value: showingDailyPractice)
        .sheet(isPresented: $showingDashboard) {
            // Left exactly as it was: the caregiver dashboard is out of scope for this
            // pass and keeps its own presentation and visual language.
            CaregiverDashboardView()
        }
    }

    private var screens: some View {
        VStack(spacing: 0) {
            switch appModel.phase {
            case .welcome, .openingActivity:
                welcome
            case .inActivity:
                inActivity
            case .finished:
                finished
            }
        }
        .padding(44)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(RehabMotion.honouring(reduceMotion), value: appModel.phase)
        .onAppear { now = .now }
        .onChange(of: appModel.phase) { _, phase in
            if phase == .welcome { now = .now }
        }
    }

    // MARK: - Home

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 26) {
            header
                .rehabEntrance(0)

            dailyPracticeCard
                .rehabEntrance(1)

            featuredExercise
                .rehabEntrance(2)

            games
                .rehabEntrance(3)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: 640, alignment: .leading)
        .transition(.opacity)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(dateLine)
                    .font(.rehabLabel)
                    .foregroundStyle(.secondary)

                BilingualText(
                    english: "\(timeOfDayGreeting), \(DemoPersona.owner.greetingName)",
                    chinese: "\(timeOfDayGreetingChinese)，\(DemoPersona.owner.greetingChineseName)",
                    font: .rehabTitle
                )
            }

            Spacer(minLength: 0)

            // Deliberately recessive, and last in the reading order rather than a
            // full-width button in the stack: a caregiver knows where this is, and nothing
            // about it should invite a disoriented person into a screen of charts about
            // herself.
            Button {
                showingDashboard = true
            } label: {
                Label("Caregiver Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .controlSize(.large)
        }
    }

    /// Tier one: the day's prescribed work.
    ///
    /// Basil's simulator finding on 2026-08-10 is the reason this is tinted rather than
    /// merely `.borderedProminent`: on visionOS a prominent button renders as the same
    /// glass capsule as a bordered one, so side by side the two were indistinguishable.
    /// Colour is what separates a primary action here — which is also why `RehabTint`
    /// hands out exactly one action colour and reserves orange for the "Who am I?"
    /// lifeline. Jade rather than the system blue so it never collides with a system
    /// control that happens to be on screen.
    private var dailyPracticeCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 18) {
                badge(
                    symbol: "checklist",
                    colors: [
                        Color(red: 0.30, green: 0.36, blue: 0.68),
                        Color(red: 0.14, green: 0.17, blue: 0.38)
                    ],
                    size: 84
                )

                VStack(alignment: .leading, spacing: 7) {
                    Text("Today · 今天")
                        .font(.rehabLabel)
                        .foregroundStyle(RehabTint.action)

                    BilingualText(english: "Daily Practice", chinese: "每日练习", font: .rehabHeadline)

                    Text("Four short activities, at your own pace.")
                        .font(.rehabCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            Button {
                showingDailyPractice = true
            } label: {
                Text("Start · 开始")
                    .font(.rehabBody)
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.extraLarge)
            .tint(RehabTint.action)
        }
        .rehabCard(tint: RehabTint.action)
        .rehabAttention()
    }

    /// Tier two: the one immersive exercise that is a rehabilitation task rather than a
    /// game, so it gets its own row above the games pair rather than sitting among them.
    private var featuredExercise: some View {
        activityRow(.routeMemory, badgeSize: 52)
    }

    /// Tier three. Kopi and mahjong stay one tap away rather than behind a "Games" screen:
    /// putting a step between someone and the thing they came for is exactly where a
    /// person loses the thread.
    private var games: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Games · 游戏")
                .font(.rehabLabel)
                .foregroundStyle(.secondary)

            activityRow(.coffee, badgeSize: 44)
            activityRow(.mahjong, badgeSize: 44)
        }
    }

    private func activityRow(_ kind: AppModel.ActivityKind, badgeSize: CGFloat) -> some View {
        Button {
            Task { await startActivity(kind) }
        } label: {
            HStack(spacing: 16) {
                badge(symbol: kind.symbolName, colors: kind.badgeColors, size: badgeSize)

                BilingualText(english: kind.title, chinese: kind.chineseTitle, font: .rehabBody)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.rehabCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: RehabMetrics.minTarget)
        }
        // `.borderless` rather than `.plain`: the row owns its background, and the button's
        // gaze-hover highlight takes its shape from `buttonBorderShape`, which has to match
        // the background radius or the highlight overshoots the row.
        .buttonStyle(.borderless)
        .buttonBorderShape(.roundedRectangle(radius: RehabMetrics.rowRadius))
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: RehabMetrics.rowRadius, style: .continuous)
        )
        .disabled(appModel.phase == .openingActivity)
    }

    /// A stand-in for the scene renders Aditya's 3D work will eventually supply. Keyed to
    /// each activity's actual palette so the placeholder still reads as that activity.
    private func badge(symbol: String, colors: [Color], size: CGFloat, bounce: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.42))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, options: .nonRepeating, value: bounce)
            }
            .accessibilityHidden(true)
    }

    // MARK: - During an activity

    /// Guidance while the kopi or mahjong activity runs — those spaces keep this window
    /// open as their instruction surface. Unreachable for Remember the Way: that activity
    /// dismisses this whole window (`AppModel.startWayHome`) because
    /// `RouteMemoryTableView.controlPanel` already carries the real, phase-accurate
    /// instructions and a second surface just competed for attention.
    ///
    /// The three controls at the bottom are the point of the redesign. "Say it again"
    /// replays the spoken instruction through `VoiceGuide` (there was previously no way to
    /// hear it twice); "Show me" hands over the answer *before* a mistake can happen, which
    /// is what errorless learning actually asks for; "Take a break" is a dignified exit
    /// from a screen that used to have none.
    private var inActivity: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(appModel.currentActivity.title) · \(appModel.currentActivity.chineseTitle)")
                    .font(.rehabLabel)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 12)

                if let progress = stepProgress {
                    stepDots(index: progress.index, count: progress.count)
                }
            }

            Text(instruction)
                .font(.rehabDisplay)
                .contentTransition(.opacity)
                .animation(RehabMotion.honouring(reduceMotion), value: instruction)

            if hintShown, let hint {
                HStack(spacing: 14) {
                    Image(systemName: "eye.fill")
                        .font(.rehabBody)
                        .foregroundStyle(RehabTint.action)

                    Text(hint)
                        .font(.rehabCaption)
                }
                .rehabCard(radius: RehabMetrics.rowRadius, tint: RehabTint.action)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button {
                    appModel.voice.speak(instruction, interrupting: true)
                } label: {
                    Label("Say it again", systemImage: "speaker.wave.2.fill")
                        .font(.rehabCaption)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)

                if let hint {
                    Button {
                        withAnimation(RehabMotion.honouring(reduceMotion, RehabMotion.settle)) {
                            hintShown = true
                        }
                        appModel.voice.speak(hint, interrupting: true)
                    } label: {
                        Label("Show me", systemImage: "eye.fill")
                            .font(.rehabCaption)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .disabled(hintShown)
                }

                Spacer(minLength: 0)

                Button {
                    Task { await takeABreak() }
                } label: {
                    Label("Take a break", systemImage: "pause.fill")
                        .font(.rehabCaption)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: 640, alignment: .leading)
        .transition(.opacity)
        .onChange(of: instruction) { _, _ in
            hintShown = false
        }
    }

    private func stepDots(index: Int, count: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { step in
                Circle()
                    .fill(step <= index ? RehabTint.action : Color.secondary.opacity(0.25))
                    .frame(width: step == index ? 15 : 11, height: step == index ? 15 : 11)
            }
        }
        .animation(RehabMotion.honouring(reduceMotion, RehabMotion.settle), value: index)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(index + 1) of \(count)")
    }

    /// Where the person is in a stepped activity. Only kopi has real steps —
    /// `MahjongExercise` is a turn-based game with phases rather than a fixed sequence, so
    /// it shows no dots rather than inventing a progress bar that doesn't mean anything.
    private var stepProgress: (index: Int, count: Int)? {
        guard appModel.currentActivity == .coffee, let step = appModel.coffee.currentStep else {
            return nil
        }
        return (step.rawValue, CoffeeExercise.Step.allCases.count)
    }

    private var instruction: String {
        switch appModel.currentActivity {
        case .coffee:
            appModel.coffee.currentStep?.instruction ?? "Your kopi is ready."
        case .mahjong:
            mahjongInstruction
        case .routeMemory:
            "Study the glowing route, then find the way home from memory."
        }
    }

    private var mahjongInstruction: String {
        switch appModel.mahjong.phase {
        case .loading: "Setting out the tiles."
        case .playerDraw: "Your turn — take a tile from the wall."
        case .playerDiscard: "Choose a tile you don't need, and put it down."
        case .claimWindow: "You can take that tile, or let it go."
        case .computerTurn: "Wait a moment — it's their turn."
        case .won: "You won!"
        case .drawn: "No tiles left. Shall we play again?"
        }
    }

    /// Only offered where the app can point at something real. Kopi highlights the item for
    /// the current step, so its hint names that item; mahjong has no equivalent single
    /// right answer to reveal, so it offers no "Show me" button at all rather than one that
    /// says nothing useful.
    private var hint: String? {
        switch appModel.currentActivity {
        case .coffee:
            appModel.coffee.currentStep.map { "Look for \($0.itemName) — it is glowing." }
        case .mahjong, .routeMemory:
            nil
        }
    }

    // MARK: - Finished

    private var finished: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 0)

            badge(
                symbol: appModel.currentActivity.symbolName,
                colors: appModel.currentActivity.badgeColors,
                size: 116,
                bounce: true
            )
            .rehabEntrance(0)

            BilingualText(
                english: appModel.currentActivity.completionLine(name: DemoPersona.owner.greetingName),
                chinese: appModel.currentActivity.completionLineChinese(name: DemoPersona.owner.greetingChineseName),
                font: .rehabDisplay,
                alignment: .center
            )
            .rehabEntrance(1)

            HStack(spacing: 14) {
                Button {
                    Task { await startActivity(appModel.currentActivity) }
                } label: {
                    Text("Do it again · 再来一次")
                        .font(.rehabBody)
                        .frame(minHeight: 40)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.extraLarge)
                .tint(RehabTint.action)

                Button {
                    appModel.phase = .welcome
                } label: {
                    Text("Something else · 别的")
                        .font(.rehabBody)
                        .frame(minHeight: 40)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.extraLarge)
            }
            .rehabEntrance(2)

            Spacer(minLength: 0)

            // No activity tally here any more — see the note on the type. "Something else"
            // returns to the home screen, where Daily Practice is the loudest thing on
            // screen, so nothing is lost by dropping the secondary buttons that were here.
        }
        .frame(maxWidth: 640)
        .transition(.opacity)
    }

    // MARK: - Copy

    private var dateLine: String {
        let english = now.formatted(
            Date.FormatStyle()
                .weekday(.wide)
                .day()
                .month(.wide)
                .locale(Locale(identifier: "en_SG"))
        )
        let chinese = now.formatted(
            Date.FormatStyle()
                .weekday(.wide)
                .locale(Locale(identifier: "zh_Hans_SG"))
        )
        return "\(english) · \(chinese)"
    }

    private var timeOfDayGreeting: String {
        switch Calendar.current.component(.hour, from: now) {
        case 0..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }

    private var timeOfDayGreetingChinese: String {
        switch Calendar.current.component(.hour, from: now) {
        case 0..<12: "早安"
        case 12..<18: "午安"
        default: "晚安"
        }
    }

    // MARK: - Actions

    private func startActivity(_ activity: AppModel.ActivityKind) async {
        hintShown = false

        // Remember the Way dismisses this window (its immersive control panel is the
        // only guidance surface) and is shared with the name card's "Show me the way
        // home" — see AppModel.startWayHome. Kopi and mahjong keep the window open as
        // their guidance surface (`inActivity` above).
        if activity == .routeMemory {
            await appModel.startWayHome(openImmersiveSpace: openImmersiveSpace, dismissWindow: dismissWindow)
            return
        }

        appModel.phase = .openingActivity
        appModel.currentActivity = activity
        switch activity {
        case .routeMemory:
            appModel.routeMemory.begin()
        case .coffee:
            appModel.coffee.begin()
        case .mahjong:
            appModel.mahjong.begin()
        }
        switch await openImmersiveSpace(id: AppModel.activitySpaceID) {
        case .opened:
            appModel.phase = .inActivity
        case .userCancelled, .error:
            appModel.phase = .welcome
        @unknown default:
            appModel.phase = .welcome
        }
    }

    /// Leaves the activity without finishing it. Closing the space is enough — each
    /// activity view's `onDisappear` already returns `phase` to `.welcome` when it was
    /// still `.inActivity`, so this deliberately doesn't set the phase itself and can't
    /// race with that teardown.
    private func takeABreak() async {
        appModel.voice.stop()
        await dismissImmersiveSpace()
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
