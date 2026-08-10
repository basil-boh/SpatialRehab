import SwiftUI

/// The home window, kept deliberately plain: native glass, a greeting, and
/// exactly one activity card ("Something else" swaps what the card offers —
/// never a menu). Phases cross-fade in place: welcome → a calm waiting view
/// while an activity runs → the postcard mint when it ends. Clinical tools
/// hide behind a quiet caregiver reveal; "Who am I?" rides the window's
/// bottom ornament (see `SpatialRehabApp`).
struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var showingDashboard = false
    @State private var showingDailyPractice = false
    /// The keepsake minted for the activity just finished; nil until the
    /// finished overlay appears, reset when a new activity starts.
    @State private var minted: Postcard?
    /// "Something else" advances this — the single card swaps its offer.
    @State private var suggestionOffset = 0
    /// Clinical tools stay collapsed until a caregiver reveals them.
    @State private var showCaregiverTools = false
    /// Fades the welcome content out while the immersive space opens.
    @State private var launching = false

    var body: some View {
        Group {
            if showingDailyPractice {
                DailyPracticeHubView(onExit: { showingDailyPractice = false })
            } else {
                Group {
                    switch appModel.phase {
                    case .welcome, .openingActivity:
                        welcome.transition(.opacity)
                    case .inActivity:
                        inActivity.transition(.opacity)
                    case .finished:
                        finished.transition(.opacity)
                    }
                }
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .sheet(isPresented: $showingDashboard) {
                    CaregiverDashboardView()
                }
            }
        }
        .fontDesign(.rounded)
        .onChange(of: appModel.phase) { _, newPhase in
            if newPhase == .welcome || newPhase == .finished {
                launching = false
            }
        }
    }

    // MARK: - Welcome: one card, nothing else

    private var welcome: some View {
        VStack(spacing: 30) {
            Spacer()

            VStack(spacing: 8) {
                Text(greeting)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                Text("What would you like to do today?")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                if appModel.garden.coins > 0 {
                    Label("\(appModel.garden.coins)", systemImage: "star.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GardenAccent.amber)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 4)
                }
            }

            activityCard(displayedActivity)
                .id(displayedActivity)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            Button {
                withAnimation(.spring(duration: 0.55)) {
                    suggestionOffset += 1
                }
            } label: {
                Label("Something else", systemImage: "arrow.trianglehead.2.clockwise")
                    .font(.callout)
            }
            .buttonStyle(.borderless)

            Spacer()

            caregiverCorner
        }
        .opacity(launching ? 0 : 1)
        .scaleEffect(launching ? 0.96 : 1)
    }

    /// Clinical tools are the caregiver's, not the patient's — one quiet
    /// line keeps them out of her decision space entirely.
    @ViewBuilder
    private var caregiverCorner: some View {
        if showCaregiverTools {
            HStack(spacing: 14) {
                Button {
                    showingDailyPractice = true
                } label: {
                    Label("Daily Practice", systemImage: "checklist")
                }
                .buttonStyle(.bordered)

                Button {
                    showingDashboard = true
                } label: {
                    Label("Caregiver Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                }
                .buttonStyle(.bordered)

                Button {
                    withAnimation(.spring(duration: 0.4)) {
                        showCaregiverTools = false
                    }
                } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
            }
            .transition(.opacity)
        } else {
            Button {
                withAnimation(.spring(duration: 0.4)) {
                    showCaregiverTools = true
                }
            } label: {
                Label("For caregivers", systemImage: "stethoscope")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.borderless)
        }
    }

    // MARK: - In activity: calm waiting

    private var inActivity: some View {
        VStack(spacing: 20) {
            Image(systemName: activitySymbol(appModel.currentActivity))
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(GardenAccent.jade)
                .frame(width: 72, height: 72)
                .background(GardenAccent.jade.opacity(0.14), in: RoundedRectangle(cornerRadius: 18))
                .symbolEffect(.breathe, options: .repeating.speed(0.4))

            VStack(spacing: 8) {
                Text("Look at the table")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text(inActivityGuidance)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }
        }
    }

    // MARK: - Finished: the postcard mint

    private var finished: some View {
        VStack(spacing: 24) {
            Text(greeting)
                .font(.system(size: 34, weight: .bold, design: .rounded))

            if let minted {
                PostcardMintView(postcard: minted)
                    .frame(height: 230)
            }

            Button {
                withAnimation(.spring(duration: 0.6)) {
                    appModel.phase = .welcome
                }
            } label: {
                Label("Back home", systemImage: "house.fill")
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.extraLarge)
            .tint(GardenAccent.jade)
        }
        .onAppear {
            // Mint exactly one keepsake per completion; `minted` resets when
            // the next activity starts.
            guard minted == nil else { return }
            let points: Int
            switch appModel.currentActivity {
            case .mahjong: points = max(appModel.mahjong.points, 1)
            case .coffee: points = 12
            case .routeMemory: points = 15
            }
            minted = appModel.garden.record(activity: appModel.currentActivity, points: points)
        }
    }

    // MARK: - Pieces

    /// "Good morning, Chio Bu" — her name from the Who-am-I persona.
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let daypart = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
        let givenName = DemoPersona.owner.englishName
            .split(separator: " ").dropFirst().joined(separator: " ")
        switch appModel.phase {
        case .finished: return "Well done, \(givenName.isEmpty ? "friend" : String(givenName))!"
        default: return givenName.isEmpty ? "\(daypart)!" : "\(daypart), \(givenName)"
        }
    }

    /// The single offered activity: least-played first, and "Something else"
    /// walks forward through the rest — one card on screen, always.
    private var displayedActivity: AppModel.ActivityKind {
        let garden = appModel.garden
        let ordered = ([
            (AppModel.ActivityKind.coffee, garden.kopiCount),
            (.mahjong, garden.mahjongCount),
            (.routeMemory, garden.routeCount),
        ] as [(AppModel.ActivityKind, Int)])
            .sorted { $0.1 < $1.1 }
            .map(\.0)
        return ordered[suggestionOffset % ordered.count]
    }

    private func activitySymbol(_ activity: AppModel.ActivityKind) -> String {
        switch activity {
        case .coffee: return "cup.and.saucer.fill"
        case .mahjong: return "square.grid.3x3.fill"
        case .routeMemory: return "map.fill"
        }
    }

    private func activityCard(_ activity: AppModel.ActivityKind) -> some View {
        let (title, line): (String, String) = {
            switch activity {
            case .coffee: return ("Make a Cup of Kopi", "Pour, stir, and smell the morning")
            case .mahjong: return ("Play Mahjong", "The table is set for four")
            case .routeMemory: return ("Remember the Way", "A stroll home through Tiong Bahru")
            }
        }()
        return Button {
            Task {
                withAnimation(.easeIn(duration: 0.35)) {
                    launching = true
                }
                try? await Task.sleep(for: .milliseconds(380))
                await startActivity(activity)
            }
        } label: {
            HStack(spacing: 18) {
                Image(systemName: activitySymbol(activity))
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(GardenAccent.jade)
                    .frame(width: 68, height: 68)
                    .background(GardenAccent.jade.opacity(0.16), in: RoundedRectangle(cornerRadius: 18))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.forward.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(GardenAccent.jade)
            }
            .padding(22)
            .frame(maxWidth: 560)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26))
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .disabled(appModel.phase == .openingActivity)
    }

    private var inActivityGuidance: String {
        switch appModel.currentActivity {
        case .routeMemory:
            return "Study the glowing route, then find the way home from memory."
        case .coffee:
            return "Follow the glowing tags and make your kopi, one step at a time."
        case .mahjong:
            // Rarely seen: the window is dismissed while mahjong runs (its
            // immersive panel is the single guidance surface).
            return "The table will guide you — take a tile, then throw one."
        }
    }

    private func startActivity(_ activity: AppModel.ActivityKind) async {
        minted = nil
        // Remember the Way dismisses this window (its immersive control panel is the
        // only guidance surface) and is shared with the name card's "Show me the way
        // home" — see AppModel.startWayHome. Kopi keeps the window as its guidance
        // surface; mahjong dismisses it (its floating panel is the only guide).
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
            if activity == .mahjong {
                dismissWindow(id: SceneID.main)
            }
        case .userCancelled, .error:
            appModel.phase = .welcome
        @unknown default:
            appModel.phase = .welcome
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
