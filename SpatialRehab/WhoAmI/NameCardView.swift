import SwiftUI

/// Floating NRIC-style card: face side, family flip side, and greeting video turn.
struct NameCardView: View {
    @Bindable var session: WhoAmISessionModel
    @Environment(\.dismissWindow) private var dismissWindow

    private var owner: FamilyMember { session.owner }

    var body: some View {
        ZStack {
            if session.playingMemberID != nil {
                greetingTurn
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.92).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                cardBody
                    .rotation3DEffect(
                        .degrees(session.cardSide == .tree ? 180 : 0),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.45
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.orange.opacity(0.5), .yellow.opacity(0.35), .orange.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        }
        .shadow(color: .orange.opacity(session.phase == .presenting ? 0.55 : 0.22), radius: session.phase == .presenting ? 36 : 18)
        .scaleEffect(session.phase == .presenting ? 1.04 : (session.phase == .puttingAway ? 0.55 : 1.0))
        .opacity(session.phase == .puttingAway ? 0.15 : 1.0)
        .offset(y: session.phase == .puttingAway ? 80 : 0)
        .animation(.spring(response: 0.55, dampingFraction: 0.82), value: session.phase)
        .animation(.easeInOut(duration: 0.45), value: session.playingMemberID)
        .onChange(of: session.isCardWindowOpen) { _, open in
            if !open {
                dismissWindow(id: "name-card")
            }
        }
        .onDisappear {
            // User may close the window with the system control; keep session in sync.
            if session.isCardWindowOpen, session.phase != .puttingAway {
                session.isCardWindowOpen = false
                session.phase = .nest
                session.glowProgress = 0
                session.playingMemberID = nil
            }
        }
    }

    @ViewBuilder
    private var cardBody: some View {
        if session.cardSide == .face {
            faceSide
        } else {
            FamilyTreeView(session: session)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
    }

    private var faceSide: some View {
        VStack(spacing: 22) {
            HStack {
                Text("NAME CARD")
                    .font(.caption.weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("身份证式")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .center, spacing: 28) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.orange.opacity(0.35), .yellow.opacity(0.12)],
                                center: .center,
                                startRadius: 10,
                                endRadius: 90
                            )
                        )
                        .frame(width: 150, height: 150)
                        .overlay {
                            Circle()
                                .strokeBorder(.orange.opacity(0.5), lineWidth: 3)
                        }
                        .shadow(color: .orange.opacity(0.35), radius: 16)
                    Text(owner.emoji)
                        .font(.system(size: 72))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(owner.englishName)
                        .font(.system(size: 34, weight: .semibold))
                    Text(owner.chineseName)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.secondary)
                    if let birthday = owner.formattedBirthday {
                        Label(birthday, systemImage: "gift.fill")
                            .font(.title3)
                            .foregroundStyle(.orange)
                            .padding(.top, 4)
                    }
                    Text("This is you")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }

            Spacer(minLength: 8)

            HStack(spacing: 16) {
                Button {
                    session.flipToFamily()
                } label: {
                    Label("Family", systemImage: "person.3.fill")
                        .font(.title3.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(.orange)
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
        .padding(28)
    }

    private var greetingTurn: some View {
        let member = session.playingMember
        return VStack(spacing: 20) {
            Text(member?.hasGreetingVideo == true ? "Greeting" : "Family")
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(.secondary)

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.orange.opacity(0.25),
                                Color.yellow.opacity(0.15),
                                Color.orange.opacity(0.2),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 220)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(.orange.opacity(0.4), lineWidth: 2)
                    }

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

            if let member {
                Text(member.englishName)
                    .font(.title.weight(.semibold))
                Text(member.chineseName)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(member.bilingualRelation)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.orange.opacity(0.12)))

                if let line = member.videoLine, member.hasGreetingVideo {
                    Text("“\(line)”")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .padding(.top, 4)
                } else {
                    Text("A short greeting will play here soon.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: session.videoProgress)
                .tint(.orange)
                .padding(.horizontal, 40)
                .padding(.top, 8)

            Text("Closes automatically")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
