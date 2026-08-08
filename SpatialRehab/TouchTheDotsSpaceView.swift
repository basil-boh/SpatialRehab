import RealityKit
import SwiftUI

struct TouchTheDotsSpaceView: View {
    private static let dotName = "dot"

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var root = Entity()

    var body: some View {
        RealityView { content, attachments in
            content.add(root)
            if let prompt = attachments.entity(for: "prompt") {
                prompt.position = [0, 1.85, -1.3]
                content.add(prompt)
            }
            spawnNextDot()
        } attachments: {
            Attachment(id: "prompt") {
                Text(appModel.dotsGame.isFinished ? "Well done!" : "Touch the glowing circle")
                    .font(.extraLargeTitle)
                    .padding(36)
                    .glassBackgroundEffect()
            }
        }
        .gesture(
            TapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    pop(value.entity)
                }
        )
        .onDisappear {
            if appModel.phase == .inActivity {
                appModel.phase = .welcome
            }
        }
    }

    private func spawnNextDot() {
        let dot = ModelEntity(
            mesh: .generateSphere(radius: 0.06),
            materials: [UnlitMaterial(color: .systemYellow)]
        )
        dot.name = Self.dotName
        dot.position = appModel.dotsGame.nextDotPosition()
        // Collision sphere is larger than the visible dot for a forgiving hit target.
        dot.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.09)]))
        dot.components.set(InputTargetComponent())
        dot.components.set(HoverEffectComponent())
        root.addChild(dot)
        appModel.dotsGame.dotShown()
    }

    private func pop(_ entity: Entity) {
        guard entity.name == Self.dotName else { return }
        entity.name = ""
        appModel.dotsGame.dotPopped()

        var transform = entity.transform
        transform.scale = SIMD3<Float>(repeating: 1.6)
        entity.move(to: transform, relativeTo: entity.parent, duration: 0.2, timingFunction: .easeOut)

        Task {
            try? await Task.sleep(for: .milliseconds(220))
            entity.removeFromParent()
            if appModel.dotsGame.isFinished {
                try? await Task.sleep(for: .seconds(2.5))
                appModel.phase = .finished
                await dismissImmersiveSpace()
            } else {
                spawnNextDot()
            }
        }
    }
}
