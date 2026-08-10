import AVKit
import SwiftUI

/// Plays a bundled family greeting once, then reports completion.
struct GreetingVideoView: View {
    let url: URL
    let onFinished: () -> Void

    @State private var player = AVPlayer()

    var body: some View {
        VideoPlayer(player: player)
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.orange.opacity(0.4), lineWidth: 1)
            }
            .onAppear {
                player.replaceCurrentItem(with: AVPlayerItem(url: url))
                player.play()
            }
            .onReceive(NotificationCenter.default.publisher(
                for: AVPlayerItem.didPlayToEndTimeNotification
            )) { note in
                if (note.object as? AVPlayerItem) === player.currentItem {
                    onFinished()
                }
            }
            .onDisappear {
                player.pause()
            }
    }
}

/// Floating identity card: portrait face side, family flip side, and greeting video turn.
///
/// Design notes: the card chrome is layered glass — system material, then a warm amber
/// wash, then a hairline gradient border — so it reads as a physical keepsake rather than
/// a flat panel. Entrances are choreographed (portrait first, then text rows, then
/// actions, ~60 ms apart) and a one-shot light sheen sweeps the card when it presents;
/// both are skipped under Reduce Motion. All timings stay slow and springy on purpose:
/// this card is for a person with dementia, so nothing on it should ever startle.
struct NameCardView: View {
    @Bindable var session: WhoAmISessionModel
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Drives the staggered content reveal on the face side.
    @State private var revealed = false
    /// One-shot sheen position: -1 parked off the leading edge, 1 off the trailing edge.
    @State private var sheenPhase: CGFloat = -1
    /// The sheen layer only exists while it sweeps — a permanently mounted
    /// `.plusLighter` layer over glass invites compositing artifacts.
    @State private var sheenActive = false
    /// Gentle breathing glow behind the portrait.
    @State private var portraitGlow = false

    private var owner: FamilyMember { session.owner }

    private static let cardShape = RoundedRectangle(cornerRadius: 32, style: .continuous)

    var body: some View {
        ZStack {
            if session.playingMemberID != nil {
                greetingTurn
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.94).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else if session.cardSide == .face {
                // Gentle crossfade between sides — a 3D flip z-fights the
                // window glass on device and mirrors the tree mid-turn.
                faceSide
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                FamilyTreeView(session: session)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background {
            cardChrome
        }
        .overlay { sheen }
        .clipShape(Self.cardShape)
        .overlay {
            Self.cardShape
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.55),
                            .orange.opacity(0.35),
                            .white.opacity(0.12),
                            .orange.opacity(0.45),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        // No .shadow on the card: it is a material surface, and shadowing a material
        // forces offscreen compositing that intermittently renders as a gray box on
        // device (user screenshot, 2026-08-09). The window's own glass provides depth.
        .scaleEffect(session.phase == .presenting ? 1.04 : (session.phase == .puttingAway ? 0.55 : 1.0))
        .opacity(session.phase == .puttingAway ? 0.15 : 1.0)
        .offset(y: session.phase == .puttingAway ? 80 : 0)
        .animation(.spring(response: 0.55, dampingFraction: 0.82), value: session.phase)
        .animation(.easeInOut(duration: 0.45), value: session.playingMemberID)
        .animation(.easeInOut(duration: 0.45), value: session.cardSide)
        .onAppear(perform: beginPresentation)
        .onChange(of: session.isCardWindowOpen) { _, open in
            if !open {
                dismissWindow(id: SceneID.nameCard)
            }
        }
        .onDisappear {
            // User may close the window with the system control; keep session in sync.
            if session.isCardWindowOpen, session.phase != .puttingAway {
                session.isCardWindowOpen = false
                session.phase = .closed
                session.playingMemberID = nil
            }
        }
    }

    // MARK: - Card chrome

    /// Glass, then a warm dawn wash rising from the bottom-leading corner, then a huge
    /// faint watermark of the app's map motif — three quiet layers that read as depth.
    private var cardChrome: some View {
        ZStack {
            Self.cardShape.fill(.ultraThinMaterial)

            RadialGradient(
                colors: [.orange.opacity(0.16), .clear],
                center: .bottomLeading,
                startRadius: 40,
                endRadius: 520
            )

            RadialGradient(
                colors: [.yellow.opacity(0.10), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )

            Image(systemName: "person.text.rectangle")
                .font(.system(size: 340, weight: .ultraLight))
                .foregroundStyle(.black.opacity(0.12))
                .rotationEffect(.degrees(-8))
                .offset(x: 130, y: 120)
                .accessibilityHidden(true)
        }
    }

    /// One-shot diagonal light sweep when the card presents. Purely decorative,
    /// so it is skipped entirely under Reduce Motion, and unmounted once done.
    @ViewBuilder
    private var sheen: some View {
        if !reduceMotion, sheenActive {
            GeometryReader { geo in
                LinearGradient(
                    colors: [.clear, .white.opacity(0.28), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geo.size.width * 0.45)
                .rotationEffect(.degrees(18))
                .offset(x: sheenPhase * geo.size.width * 1.4)
                .blendMode(.plusLighter)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func beginPresentation() {
        guard !revealed else { return }
        if reduceMotion {
            revealed = true
            return
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.15)) {
            revealed = true
        }
        sheenActive = true
        withAnimation(.easeInOut(duration: 1.1).delay(0.45)) {
            sheenPhase = 1.6
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            sheenActive = false
        }
        // Was `.repeatForever` — an unbounded animation forces this view's body to
        // re-evaluate every frame for as long as the card window stays open, which is
        // almost certainly what was behind "onChange(of: Bool) action tried to update
        // multiple times per frame" on `session.isCardWindowOpen` below (continuous
        // re-render of a view alongside `@Observable` change-tracking is a known
        // trigger for spurious onChange re-firing) and the general slowness reported
        // alongside it. A few gentle breaths read the same to the eye and then settle
        // — perpetual motion isn't calm either, for an audience this app is careful
        // not to startle.
        withAnimation(.easeInOut(duration: 3.2).repeatCount(3, autoreverses: true).delay(0.8)) {
            portraitGlow = true
        }
    }

    /// Shared stagger for the face-side reveal: each row fades up a beat after the last.
    private func revealStyle<Content: View>(_ content: Content, step: Int) -> some View {
        content
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 14)
            .animation(
                reduceMotion
                    ? nil
                    : .spring(response: 0.55, dampingFraction: 0.85).delay(0.12 + Double(step) * 0.06),
                value: revealed
            )
    }

    // MARK: - Face side

    private var faceSide: some View {
        VStack(spacing: 20) {
            revealStyle(header, step: 0)
            revealStyle(hairline, step: 0)
            revealStyle(todayStrip, step: 1)

            HStack(alignment: .center, spacing: 30) {
                revealStyle(portrait, step: 1)

                VStack(alignment: .leading, spacing: 12) {
                    revealStyle(
                        Text("THIS IS YOU · 这是您")
                            .font(.footnote.weight(.semibold))
                            .tracking(2)
                            .foregroundStyle(.orange),
                        step: 2
                    )

                    revealStyle(
                        VStack(alignment: .leading, spacing: 2) {
                            Text(owner.englishName)
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                            Text(owner.chineseName)
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(.secondary)
                        },
                        step: 3
                    )

                    revealStyle(detailChips, step: 4)
                }
                Spacer(minLength: 0)
            }

            revealStyle(homeAndWork, step: 5)

            if let aboutMe = owner.aboutMe {
                revealStyle(
                    Text(aboutMe)
                        .font(.system(.callout, design: .serif))
                        .italic()
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity),
                    step: 6
                )
            }

            Spacer(minLength: 4)

            revealStyle(hairline, step: 6)
            revealStyle(actions, step: 6)
        }
        .padding(28)
        // The window is sized for the family tree; cap the face so its content stays
        // a composed card rather than stretching edge to edge.
        .frame(maxWidth: 700)
    }

    /// ID-card style data zone: where home is, what their life's work was, and who
    /// to call when help is needed.
    @ViewBuilder
    private var homeAndWork: some View {
        let rows: [(icon: String, label: String, value: String)] = [
            owner.homeAddress.map { ("house.fill", "HOME · 住址", $0) },
            owner.occupation.map { ("briefcase.fill", "LIFE'S WORK · 职业", $0) },
            owner.emergencyContact.map { ("phone.fill", "IF YOU NEED HELP · 求助", $0) },
        ].compactMap { $0 }

        if !rows.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 {
                        Divider()
                            .overlay(.orange.opacity(0.15))
                            .padding(.leading, 64)
                    }
                    detailRow(icon: row.icon, label: row.label, value: row.value)
                }
            }
            // Solid translucent fill, not a material — this zone sits on the card's
            // glass, and nesting materials is what glitched the tree side.
            .background(.white.opacity(0.3), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.orange.opacity(0.2), lineWidth: 1)
            }
        }
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.orange)
                .frame(width: 36, height: 36)
                .background(.orange.opacity(0.12), in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.weight(.medium))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Label {
                Text("MEMORY CARD")
                    .font(.footnote.weight(.semibold))
                    .tracking(2.5)
            } icon: {
                Image(systemName: "sparkles")
                    .font(.footnote)
            }
            .foregroundStyle(.secondary)

            Spacer()

            Text("记忆卡")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.orange.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.orange.opacity(0.1), in: .capsule)
        }
    }

    /// Reality-orientation strip: dementia erodes temporal orientation first, so the
    /// card leads with what day it is, in both languages. Recomputed on each render —
    /// the card is short-lived, so no midnight-refresh plumbing is needed.
    private var todayStrip: some View {
        Label {
            Text(todayLine)
                .font(.callout.weight(.medium))
        } icon: {
            Image(systemName: "sun.max.fill")
                .font(.callout)
                .foregroundStyle(.orange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.white.opacity(0.3), in: .capsule)
        .overlay {
            Capsule().strokeBorder(.orange.opacity(0.2), lineWidth: 1)
        }
        .frame(maxWidth: .infinity)
    }

    private var todayLine: String {
        let english = Date.now.formatted(
            Date.FormatStyle()
                .weekday(.wide)
                .day()
                .month(.wide)
                .locale(Locale(identifier: "en_SG"))
        )
        let chineseWeekday = Date.now.formatted(
            Date.FormatStyle()
                .weekday(.wide)
                .locale(Locale(identifier: "zh_CN"))
        )
        return "Today is \(english) · \(chineseWeekday)"
    }

    private var hairline: some View {
        LinearGradient(
            colors: [.orange.opacity(0.4), .orange.opacity(0.08), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
    }

    private var portrait: some View {
        Group {
            if let photoName = owner.photoName {
                Image(photoName)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RadialGradient(
                        colors: [.orange.opacity(0.35), .yellow.opacity(0.12)],
                        center: .center,
                        startRadius: 10,
                        endRadius: 110
                    )
                    Text(owner.emoji)
                        .font(.system(size: 80))
                }
            }
        }
        .frame(width: 220, height: 264)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.7), .orange.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        }
        .shadow(color: .orange.opacity(portraitGlow ? 0.38 : 0.2), radius: portraitGlow ? 26 : 16, y: 6)
        .accessibilityLabel("Your photo")
    }

    private var detailChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let birthday = owner.formattedBirthday {
                chip(icon: "gift.fill", text: birthday)
            }
            if let age = owner.age {
                chip(icon: "heart.fill", text: "\(age) years young · \(age)岁")
            }
            if let icNumber = owner.icNumber {
                chip(icon: "person.text.rectangle", text: "IC · \(icNumber)")
            }
        }
    }

    private func chip(icon: String, text: String) -> some View {
        Label {
            Text(text)
                .font(.callout.weight(.medium))
        } icon: {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(.orange)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.white.opacity(0.3), in: .capsule)
        .overlay {
            Capsule().strokeBorder(.orange.opacity(0.25), lineWidth: 1)
        }
    }

    /// "Show me the way home" is the one prominent action on the card — for a person
    /// who opened this because they feel lost, that is the button that matters most.
    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                Task { await showWayHome() }
            } label: {
                Label("Show me the way home · 带我回家", systemImage: "house.fill")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.orange)
            .controlSize(.large)
            .disabled(appModel.phase == .openingActivity)

            HStack(spacing: 16) {
                Button {
                    session.flipToFamily()
                } label: {
                    Label("My Family · 家人", systemImage: "person.3.fill")
                        .font(.title3.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)

                Button {
                    session.putAway()
                } label: {
                    Label("Put away", systemImage: "arrow.down.right.and.arrow.up.left")
                        .font(.title3.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
            }
        }
    }

    /// Starts the Remember the Way activity and retracts the card. If the person is
    /// already in (or entering) the activity — the card can be summoned from its control
    /// panel — just put the card away rather than restarting their route.
    private func showWayHome() async {
        if appModel.phase == .inActivity || appModel.phase == .openingActivity {
            session.putAway()
            return
        }
        session.putAway()
        await appModel.startWayHome(openImmersiveSpace: openImmersiveSpace, dismissWindow: dismissWindow)
    }

    // MARK: - Greeting turn

    private var greetingTurn: some View {
        let member = session.playingMember
        return VStack(spacing: 18) {
            Label {
                Text(member?.hasGreetingVideo == true ? "A GREETING FOR YOU" : "YOUR FAMILY")
                    .font(.footnote.weight(.semibold))
                    .tracking(2.5)
            } icon: {
                Image(systemName: member?.hasGreetingVideo == true ? "video.fill" : "person.2.fill")
                    .font(.footnote)
            }
            .foregroundStyle(.secondary)

            if let member, let url = member.videoURL {
                GreetingVideoView(url: url) {
                    session.finishGreeting(for: member.id)
                }
                .shadow(color: .orange.opacity(0.2), radius: 18, y: 6)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.orange.opacity(0.22),
                                    Color.yellow.opacity(0.12),
                                    Color.orange.opacity(0.18),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 220)
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
                        }

                    greetingFace(for: member)
                }
                .shadow(color: .orange.opacity(0.15), radius: 14, y: 5)
            }

            if let member {
                VStack(spacing: 4) {
                    Text(member.englishName)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text(member.chineseName)
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text(member.bilingualRelation)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(.orange.opacity(0.1), in: .capsule)
                    .overlay {
                        Capsule().strokeBorder(.orange.opacity(0.3), lineWidth: 1)
                    }

                // Not gated on `hasGreetingVideo`: a relative with only a looping
                // portrait still has something to say, and the old gate meant their
                // line would silently never render.
                if let line = member.videoLine {
                    Text("“\(line)”")
                        .font(.system(.title3, design: .serif))
                        .italic()
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary.opacity(0.9))
                        .padding(.top, 2)
                } else {
                    Text("A short greeting will play here soon.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if member?.videoURL == nil {
                ProgressView(value: session.videoProgress)
                    .tint(.orange)
                    .padding(.horizontal, 48)
                    .padding(.top, 6)
            }

            Label("Closes on its own", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(28)
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// What fills the slab when a relative has no spoken greeting recorded yet.
    ///
    /// Falls back in order of how much it looks like a person: the looping portrait
    /// first, then the still photo, and only then the emoji. A cartoon emoji where a
    /// face should be reads as a missing asset — the worst thing to show someone who
    /// opened this card to remember who a relative is.
    @ViewBuilder
    private func greetingFace(for member: FamilyMember?) -> some View {
        if let member, let portraitURL = member.portraitVideoURL {
            MovingPortraitView(url: portraitURL) {
                greetingStillFace(for: member)
            }
            .frame(width: 176, height: 176)
            .overlay {
                Circle().strokeBorder(.orange.opacity(0.35), lineWidth: 2)
            }
        } else if let member, member.photoName != nil {
            greetingStillFace(for: member)
                .frame(width: 176, height: 176)
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(.orange.opacity(0.35), lineWidth: 2)
                }
        } else {
            VStack(spacing: 12) {
                Text(member?.emoji ?? "👤")
                    .font(.system(size: 80))
                if member?.hasGreetingVideo == true {
                    Image(systemName: "play.circle.fill")
                        .font(.title)
                        .foregroundStyle(.orange)
                        .symbolEffect(.pulse, options: .repeating)
                }
            }
        }
    }

    /// Still face used both on its own and as the layer beneath a moving portrait.
    @ViewBuilder
    private func greetingStillFace(for member: FamilyMember) -> some View {
        if let photoName = member.photoName {
            Image(photoName)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [.orange.opacity(0.25), .yellow.opacity(0.2)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Text(member.emoji)
                    .font(.system(size: 84))
            }
        }
    }
}
