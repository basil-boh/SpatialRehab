import SwiftUI

/// Home object the name card flies out of and returns to.
struct NestView: View {
    let glow: Double
    let isReceivingCard: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.95, blue: 0.82),
                            Color(red: 1.0, green: 0.90, blue: 0.70),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.orange.opacity(0.35 + glow * 0.4), lineWidth: 2)
                }
                .shadow(color: .orange.opacity(0.25 + glow * 0.45), radius: 16 + glow * 20)

            VStack(spacing: 10) {
                ZStack {
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.green.opacity(0.85))
                        .symbolRenderingMode(.hierarchical)
                    Image(systemName: "person.crop.rectangle.stack.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.orange)
                        .offset(y: 4)
                }
                .scaleEffect(isReceivingCard ? 1.12 : 1.0)

                Text("Family nest")
                    .font(.headline)
                Text("Your name card lives here")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .frame(width: 200, height: 180)
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: isReceivingCard)
        .animation(.easeInOut(duration: 0.4), value: glow)
    }
}
