import SwiftUI

/// Freehand path pad for Simulator (drag) and as a clear target zone for hand pinch-circle on device.
struct CircleDrawCanvas: View {
    @Bindable var session: WhoAmISessionModel

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.orange.opacity(0.06))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(
                                AngularGradient(
                                    colors: [
                                        .orange.opacity(0.15 + session.glowProgress * 0.55),
                                        .yellow.opacity(0.2 + session.glowProgress * 0.5),
                                        .orange.opacity(0.15 + session.glowProgress * 0.55),
                                    ],
                                    center: .center
                                ),
                                lineWidth: 3 + session.glowProgress * 6
                            )
                    }
                    .shadow(color: .orange.opacity(session.glowProgress * 0.55), radius: 18 + session.glowProgress * 24)

                // Soft guide ring
                Circle()
                    .strokeBorder(.orange.opacity(0.18), style: StrokeStyle(lineWidth: 3, dash: [10, 12]))
                    .frame(width: min(size.width, size.height) * 0.62, height: min(size.width, size.height) * 0.62)

                Path { path in
                    let pts = session.drawPoints
                    guard let first = pts.first else { return }
                    path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
                    for p in pts.dropFirst() {
                        path.addLine(to: CGPoint(x: p.x * size.width, y: p.y * size.height))
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [.orange, .yellow, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                )

                if session.glowProgress > 0.7 {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.yellow.opacity(0.45), .orange.opacity(0.15), .clear],
                                center: .center,
                                startRadius: 4,
                                endRadius: min(size.width, size.height) * 0.35
                            )
                        )
                        .frame(width: min(size.width, size.height) * 0.5, height: min(size.width, size.height) * 0.5)
                        .allowsHitTesting(false)
                }

                VStack(spacing: 8) {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.orange.opacity(0.7))
                    Text("Draw a circle with your left hand")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("Simulator: drag a loop here")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
                .opacity(session.drawPoints.isEmpty ? 1 : 0)
                .animation(.easeOut(duration: 0.25), value: session.drawPoints.isEmpty)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let p = CGPoint(
                            x: min(max(value.location.x / size.width, 0), 1),
                            y: min(max(value.location.y / size.height, 0), 1)
                        )
                        if session.drawPoints.isEmpty {
                            session.beginStroke(at: p)
                        } else {
                            session.continueStroke(to: p)
                        }
                    }
                    .onEnded { _ in
                        session.endStroke()
                    }
            )
        }
    }
}
