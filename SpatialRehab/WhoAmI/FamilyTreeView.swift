import SwiftUI

/// Soft yellow glass family tree: couple on top, three children, optional grandson under Mei Ling.
struct FamilyTreeView: View {
    @Bindable var session: WhoAmISessionModel

    private let parents = DemoPersona.parents
    private let children = DemoPersona.children

    var body: some View {
        VStack(spacing: 0) {
            Text("Family")
                .font(.title2.weight(.semibold))
                .padding(.bottom, 16)

            HStack(spacing: 28) {
                personCard(parents.husband)
                personCard(parents.selfMember, isSelf: true)
            }

            treeStem
                .frame(height: 36)

            HStack(alignment: .top, spacing: 20) {
                ForEach(children) { child in
                    VStack(spacing: 10) {
                        personCard(child)
                        grandchildSlot(for: child)
                    }
                }
            }

            Text("Gaze a photo · pinch to see them")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 20)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 1.0, green: 0.96, blue: 0.86).opacity(0.95))
        }
    }

    private var treeStem: some View {
        GeometryReader { geo in
            Path { path in
                let midX = geo.size.width / 2
                path.move(to: CGPoint(x: midX, y: 0))
                path.addLine(to: CGPoint(x: midX, y: geo.size.height * 0.45))
                path.move(to: CGPoint(x: geo.size.width * 0.12, y: geo.size.height * 0.45))
                path.addLine(to: CGPoint(x: geo.size.width * 0.88, y: geo.size.height * 0.45))
                // drops to three children
                for x in [0.18, 0.50, 0.82] {
                    let px = geo.size.width * x
                    path.move(to: CGPoint(x: px, y: geo.size.height * 0.45))
                    path.addLine(to: CGPoint(x: px, y: geo.size.height))
                }
            }
            .stroke(Color.orange.opacity(0.55), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }

    private var connectorDown: some View {
        Rectangle()
            .fill(Color.orange.opacity(0.45))
            .frame(width: 2, height: 16)
    }

    /// Fixed-height slot under every child so the tree never re-lays-out
    /// when the grandchild appears — cards and stem lines stay put.
    @ViewBuilder
    private func grandchildSlot(for child: FamilyMember) -> some View {
        VStack(spacing: 6) {
            if child.id == DemoPersona.meiLingID {
                if session.showExpandedGrandchild,
                   let szeHao = DemoPersona.member(id: DemoPersona.szeHaoID) {
                    connectorDown
                    personCard(szeHao, compact: true)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                } else {
                    Text("Pinch for grandchild")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
            }
        }
        .frame(height: 185, alignment: .top)
        .animation(.easeInOut(duration: 0.35), value: session.showExpandedGrandchild)
    }

    private func personCard(_ member: FamilyMember, isSelf: Bool = false, compact: Bool = false) -> some View {
        Button {
            if member.id == DemoPersona.selfID {
                session.flipToFace()
            } else if member.id == DemoPersona.szeHaoID {
                session.selectGrandchild(member)
            } else {
                session.selectMember(member)
            }
        } label: {
            VStack(spacing: compact ? 6 : 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.orange.opacity(isSelf ? 0.35 : 0.18),
                                    Color.yellow.opacity(0.25),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: compact ? 64 : 84, height: compact ? 64 : 84)
                        .overlay {
                            Circle()
                                .strokeBorder(isSelf ? Color.orange : Color.orange.opacity(0.35), lineWidth: isSelf ? 3 : 1.5)
                        }
                    Text(member.emoji)
                        .font(.system(size: compact ? 30 : 40))
                }

                VStack(spacing: 2) {
                    Text(member.englishName)
                        .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(member.chineseName)
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                    if !isSelf {
                        Text(member.bilingualRelation)
                            .font(.caption2)
                            .foregroundStyle(.orange.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    } else {
                        Text("You · 您自己")
                            .font(.caption2)
                            .foregroundStyle(.orange.opacity(0.9))
                    }
                }
                .frame(width: compact ? 110 : 130)
            }
            .padding(compact ? 10 : 14)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.55))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(.orange.opacity(0.25), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.roundedRectangle(radius: 18))
    }
}
