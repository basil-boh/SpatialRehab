import SwiftUI

/// Collects each tile's (and the couple's avatars') bounds so the connector lines can be
/// drawn between the real, laid-out positions — nothing is eyeballed with fractions.
private struct TileAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] { [:] }
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// The tree's plumbing, built from resolved tile rects: marriage stubs joining each
/// spouse to the heart, a stem dropping from the heart, a rail above the children, and
/// one drop into each child — so every member has a line physically touching their tile.
/// Drawn with a single `.trim` so the segments draw themselves in sequence: stubs, stem,
/// rail, then each drop.
private struct ConnectorsShape: Shape {
    var heartCenter: CGPoint
    var heartRadius: CGFloat
    var husbandEdge: CGPoint
    var selfEdge: CGPoint
    var railY: CGFloat
    var childTops: [CGPoint]
    /// Mei Ling bottom → Sze Hao top; drawn last so the trim reaches him after his mother.
    var grandchildDrop: (from: CGPoint, to: CGPoint)?

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = childTops.first, let last = childTops.last else { return path }

        path.move(to: husbandEdge)
        path.addLine(to: CGPoint(x: heartCenter.x - heartRadius, y: heartCenter.y))
        path.move(to: CGPoint(x: heartCenter.x + heartRadius, y: heartCenter.y))
        path.addLine(to: selfEdge)

        path.move(to: CGPoint(x: heartCenter.x, y: heartCenter.y + heartRadius))
        path.addLine(to: CGPoint(x: heartCenter.x, y: railY))

        path.move(to: CGPoint(x: heartCenter.x, y: railY))
        path.addLine(to: CGPoint(x: first.x, y: railY))
        path.move(to: CGPoint(x: heartCenter.x, y: railY))
        path.addLine(to: CGPoint(x: last.x, y: railY))

        for top in childTops {
            path.move(to: CGPoint(x: top.x, y: railY))
            path.addLine(to: top)
        }

        if let grandchildDrop {
            path.move(to: grandchildDrop.from)
            path.addLine(to: grandchildDrop.to)
        }
        return path
    }
}

/// Warm glass family tree in real genealogy layout: the couple joined by a heart, a stem
/// down to their three children, and the grandson tucked under Mei Ling. Connectors are
/// anchored to the tiles' actual layout, faces dominate the tiles, and the whole tree
/// assembles generation by generation — slow, springy choreography; nothing here should
/// ever startle.
struct FamilyTreeView: View {
    @Bindable var session: WhoAmISessionModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let parents = DemoPersona.parents
    private let children = DemoPersona.children

    /// Drives the staggered tile reveal.
    @State private var revealed = false
    /// Draw-in progress of the connector lines; runs after the couple has appeared.
    @State private var linesDrawn = false

    var body: some View {
        VStack(spacing: 0) {
            Label {
                Text("YOUR FAMILY · 您的家人")
                    .font(.footnote.weight(.semibold))
                    .tracking(2.5)
            } icon: {
                Image(systemName: "heart.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            .foregroundStyle(.secondary)
            .padding(.bottom, 22)
            .reveal(revealed, step: 0, reduceMotion: reduceMotion)

            HStack(alignment: .top, spacing: 56) {
                personCard(parents.husband, generation: .couple)
                    .reveal(revealed, step: 1, reduceMotion: reduceMotion)
                personCard(parents.selfMember, generation: .couple, isSelf: true)
                    .reveal(revealed, step: 2, reduceMotion: reduceMotion)
            }

            Spacer().frame(height: 56)

            HStack(alignment: .top, spacing: 32) {
                ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                    VStack(spacing: 0) {
                        personCard(child, generation: .child)
                            .reveal(revealed, step: 4 + index, reduceMotion: reduceMotion)

                        // The whole tree is always on show — the grandson lives
                        // permanently under his mother, no pinch needed to find him.
                        if child.id == DemoPersona.meiLingID,
                           let szeHao = DemoPersona.member(id: DemoPersona.szeHaoID) {
                            personCard(szeHao, generation: .grandchild)
                                .padding(.top, 32)
                                .reveal(revealed, step: 7, reduceMotion: reduceMotion)
                        }
                    }
                }
            }

            Spacer(minLength: 12)

            Label("Look at someone and pinch to meet them · 轻捏见面", systemImage: "hand.tap")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
                .reveal(revealed, step: 8, reduceMotion: reduceMotion)

            // Explicit way back — tapping your own tile also flips, but a labeled
            // button is the affordance a disoriented person can actually find.
            Button {
                session.flipToFace()
            } label: {
                Label("Back to my card · 返回名片", systemImage: "chevron.backward")
                    .font(.title3.weight(.medium))
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .padding(.top, 14)
            .reveal(revealed, step: 9, reduceMotion: reduceMotion)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlayPreferenceValue(TileAnchorKey.self) { anchors in
            GeometryReader { proxy in
                connectorLayer(proxy: proxy, anchors: anchors)
            }
            .allowsHitTesting(false)
        }
        .background {
            // Plain translucent wash, deliberately NOT a material: this panel sits on the
            // card's glass and tiles sit on it, and stacking materials on materials is
            // what caused the intermittent gray "shadow box" during interaction
            // (user screenshot, 2026-08-09). The window glass is the one material layer.
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.yellow.opacity(0.12), .orange.opacity(0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "tree")
                        .font(.system(size: 180, weight: .ultraLight))
                        .foregroundStyle(.orange.opacity(0.05))
                        .rotationEffect(.degrees(-6))
                        .offset(x: 30, y: 40)
                        .accessibilityHidden(true)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(.orange.opacity(0.2), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .onAppear {
            guard !revealed else { return }
            if reduceMotion {
                revealed = true
                linesDrawn = true
            } else {
                withAnimation { revealed = true }
                withAnimation(.easeInOut(duration: 0.9).delay(0.5)) {
                    linesDrawn = true
                }
            }
        }
    }

    // MARK: - Connectors

    /// Heart between the spouses plus the stem/rail/drop lines, all positioned from the
    /// tiles' resolved bounds so they stay glued to the layout.
    @ViewBuilder
    private func connectorLayer(proxy: GeometryProxy, anchors: [String: Anchor<CGRect>]) -> some View {
        if let husbandTile = rect(for: tileKey(parents.husband.id), in: proxy, anchors: anchors),
           let selfTile = rect(for: tileKey(parents.selfMember.id), in: proxy, anchors: anchors),
           let husbandAvatar = rect(for: avatarKey(parents.husband.id), in: proxy, anchors: anchors) {
            let childRects = children.compactMap { rect(for: tileKey($0.id), in: proxy, anchors: anchors) }
            if childRects.count == children.count {
                let heartCenter = CGPoint(
                    x: (husbandTile.maxX + selfTile.minX) / 2,
                    y: husbandAvatar.midY
                )
                let coupleBottom = max(husbandTile.maxY, selfTile.maxY)
                let railY = (coupleBottom + childRects.map(\.minY).min()!) / 2 + 8
                let childTops = childRects.map { CGPoint(x: $0.midX, y: $0.minY - 2) }
                let lineStroke = LinearGradient(
                    colors: [.orange.opacity(0.65), .orange.opacity(0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                let lineStyle = StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)

                let grandchildDrop: (from: CGPoint, to: CGPoint)? = {
                    guard let meiLingTile = rect(for: tileKey(DemoPersona.meiLingID), in: proxy, anchors: anchors),
                          let szeHaoTile = rect(for: tileKey(DemoPersona.szeHaoID), in: proxy, anchors: anchors)
                    else { return nil }
                    return (
                        from: CGPoint(x: meiLingTile.midX, y: meiLingTile.maxY + 2),
                        to: CGPoint(x: szeHaoTile.midX, y: szeHaoTile.minY - 2)
                    )
                }()

                ZStack(alignment: .topLeading) {
                    ConnectorsShape(
                        heartCenter: heartCenter,
                        heartRadius: 17,
                        husbandEdge: CGPoint(x: husbandTile.maxX, y: heartCenter.y),
                        selfEdge: CGPoint(x: selfTile.minX, y: heartCenter.y),
                        railY: railY,
                        childTops: childTops,
                        grandchildDrop: grandchildDrop
                    )
                    .trim(from: 0, to: linesDrawn ? 1 : 0)
                    .stroke(lineStroke, style: lineStyle)

                    heartNode
                        .position(heartCenter)
                }
            }
        }
    }

    /// Small glass chip with a heart, joining the couple — the classic genealogy
    /// marriage node, and the point the whole tree grows from.
    private var heartNode: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.85))
                .frame(width: 30, height: 30)
                .overlay {
                    Circle().strokeBorder(.orange.opacity(0.45), lineWidth: 1)
                }
            Image(systemName: "heart.fill")
                .font(.system(size: 13))
                .foregroundStyle(.pink.opacity(0.85))
        }
        .scaleEffect(linesDrawn ? 1 : 0.01)
        .animation(
            reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.6).delay(0.45),
            value: linesDrawn
        )
        .accessibilityHidden(true)
    }

    private func rect(for key: String, in proxy: GeometryProxy, anchors: [String: Anchor<CGRect>]) -> CGRect? {
        anchors[key].map { proxy[$0] }
    }

    private func tileKey(_ id: FamilyMember.ID) -> String { "tile-\(id.rawValue)" }
    private func avatarKey(_ id: FamilyMember.ID) -> String { "avatar-\(id.rawValue)" }

    // MARK: - Tiles

    private enum Generation {
        case couple
        case child
        case grandchild

        var avatarSize: CGFloat {
            switch self {
            case .couple: 100
            case .child: 84
            case .grandchild: 68
            }
        }

        var textWidth: CGFloat {
            switch self {
            case .couple: 150
            case .child: 146
            case .grandchild: 126
            }
        }

        var padding: CGFloat {
            switch self {
            case .couple: 18
            case .child: 16
            case .grandchild: 12
            }
        }
    }

    private func personCard(_ member: FamilyMember, generation: Generation, isSelf: Bool = false) -> some View {
        Button {
            if member.id == DemoPersona.selfID {
                session.flipToFace()
            } else if member.id == DemoPersona.szeHaoID {
                session.selectGrandchild(member)
            } else {
                session.selectMember(member)
            }
        } label: {
            // The tile surface lives inside the label (not on the Button) so the
            // background can never disagree with the content's laid-out bounds.
            VStack(spacing: generation == .grandchild ? 6 : 10) {
                avatar(for: member, generation: generation, isSelf: isSelf)

                VStack(spacing: 2) {
                    Text(member.englishName)
                        .font(generation == .grandchild ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(member.chineseName)
                        .font(generation == .grandchild ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                    Text(isSelf ? "You · 您自己" : member.bilingualRelation)
                        .font(.caption2)
                        .foregroundStyle(isSelf ? .green : .orange)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: generation.textWidth)
            }
            .padding(generation.padding)
            .background {
                // Solid translucent fill, no material and no shadow — see the panel
                // background note above for the compositing artifact both caused.
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white.opacity(isSelf ? 0.4 : 0.32))
                    .overlay {
                        if isSelf {
                            // Green, not the family amber, so "this one is me" reads
                            // at a glance.
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.green.opacity(0.16), .mint.opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                isSelf ? .green.opacity(0.65) : .orange.opacity(0.22),
                                lineWidth: isSelf ? 2 : 1
                            )
                    }
            }
            // `transform…`, not `anchorPreference`: the plain setter would REPLACE the
            // avatar anchor registered inside this same subtree, and with the husband's
            // avatar anchor gone the whole connector overlay bails out — no lines at all.
            .transformAnchorPreference(key: TileAnchorKey.self, value: .bounds) { dict, anchor in
                dict[tileKey(member.id)] = anchor
            }
        }
        .buttonStyle(.borderless)
        .buttonBorderShape(.roundedRectangle(radius: 20))
    }

    @ViewBuilder
    private func avatar(for member: FamilyMember, generation: Generation, isSelf: Bool) -> some View {
        let size = generation.avatarSize
        Group {
            if let photoName = member.photoName {
                Image(photoName)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(isSelf ? 0.35 : 0.18),
                            Color.yellow.opacity(0.25),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    Text(member.emoji)
                        .font(.system(size: size * 0.46))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(
                    isSelf ? Color.green.opacity(0.9) : Color.orange.opacity(0.35),
                    lineWidth: isSelf ? 2.5 : 1.5
                )
        }
        .overlay(alignment: .bottomTrailing) {
            if member.hasGreetingVideo {
                ZStack {
                    Circle()
                        .fill(.orange)
                        .frame(width: 22, height: 22)
                        .overlay {
                            Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1.5)
                        }
                    Image(systemName: "play.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
                .offset(x: 2, y: 2)
                .accessibilityLabel("Has a video greeting")
            }
        }
        .shadow(color: isSelf ? .green.opacity(0.3) : .orange.opacity(0.12), radius: isSelf ? 10 : 5, y: 2)
        .transformAnchorPreference(key: TileAnchorKey.self, value: .bounds) { dict, anchor in
            dict[avatarKey(member.id)] = anchor
        }
    }
}

/// Staggered fade-up used for the tree's entrance choreography.
private struct RevealModifier: ViewModifier {
    let revealed: Bool
    let step: Int
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 12)
            .animation(
                reduceMotion
                    ? nil
                    : .spring(response: 0.5, dampingFraction: 0.85).delay(0.08 + Double(step) * 0.05),
                value: revealed
            )
    }
}

private extension View {
    func reveal(_ revealed: Bool, step: Int, reduceMotion: Bool) -> some View {
        modifier(RevealModifier(revealed: revealed, step: step, reduceMotion: reduceMotion))
    }
}
