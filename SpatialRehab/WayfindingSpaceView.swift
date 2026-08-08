import RealityKit
import SwiftUI
import UIKit

@MainActor
final class WayfindingSceneController {
    /// Local positions inside `sceneRoot`: curb edge, far side of the road, bakery door.
    static let waypointPositions: [SIMD3<Float>] = [
        [0, 0, -1.7],
        [0, 0, -5.8],
        [1.3, 0, -7.4],
    ]

    private(set) var sceneRoot = Entity()
    private var redLamp: ModelEntity?
    private var greenLamp: ModelEntity?
    private var waypoints: [ModelEntity] = []

    private let redOn = UnlitMaterial(color: .systemRed)
    private let greenOn = UnlitMaterial(color: .systemGreen)
    private let lampOff = SimpleMaterial(color: UIColor(white: 0.18, alpha: 1), isMetallic: false)
    private let waypointActive = UnlitMaterial(color: .systemCyan)
    private let waypointBlocked = SimpleMaterial(color: UIColor(white: 0.45, alpha: 1), isMetallic: false)

    func install(in content: RealityViewContent, attachments: RealityViewAttachments) {
        guard sceneRoot.parent == nil else { return }
        buildStreet()
        buildTrafficLight()
        buildBakery(sign: attachments.entity(for: "bakerySign"))
        buildWaypoints()
        content.add(sceneRoot)
    }

    func apply(_ exercise: WayfindingExercise) {
        redLamp?.model?.materials = [exercise.lightState == .red ? redOn : lampOff]
        greenLamp?.model?.materials = [exercise.lightState == .green ? greenOn : lampOff]

        let blocked = exercise.nextWaypoint == WayfindingExercise.crossingWaypointIndex
            && exercise.lightState == .red
        for (index, waypoint) in waypoints.enumerated() {
            waypoint.isEnabled = index == exercise.nextWaypoint && !exercise.isFinished
        }
        if exercise.nextWaypoint < waypoints.count {
            waypoints[exercise.nextWaypoint].model?.materials = [blocked ? waypointBlocked : waypointActive]
        }
    }

    func waypointIndex(of entity: Entity) -> Int? {
        guard entity.name.hasPrefix("waypoint-") else { return nil }
        return Int(entity.name.dropFirst("waypoint-".count))
    }

    /// Locomotion moves the world, not the user: shift the scene so the
    /// chosen waypoint lands at the patient's feet.
    func moveUser(toWaypoint index: Int) {
        let target = Self.waypointPositions[index]
        sceneRoot.position = [-target.x, 0, -target.z]
    }

    func fadeScene(to opacity: Float, over duration: TimeInterval) async {
        let steps = 8
        let start = sceneRoot.components[OpacityComponent.self]?.opacity ?? 1
        for step in 1...steps {
            let progress = Float(step) / Float(steps)
            sceneRoot.components.set(OpacityComponent(opacity: start + (opacity - start) * progress))
            try? await Task.sleep(for: .milliseconds(Int(duration * 1000) / steps))
        }
    }

    private func buildStreet() {
        let sidewalk = SimpleMaterial(color: UIColor(white: 0.75, alpha: 1), isMetallic: false)
        let asphalt = SimpleMaterial(color: UIColor(white: 0.25, alpha: 1), isMetallic: false)
        let paint = SimpleMaterial(color: .white, isMetallic: false)

        addGround(width: 8, depth: 2.2, z: -0.9, material: sidewalk)
        addGround(width: 8, depth: 3.5, z: -3.75, material: asphalt)
        addGround(width: 8, depth: 2.6, z: -6.8, material: sidewalk)

        for stripe in 0..<6 {
            let box = ModelEntity(
                mesh: .generateBox(size: [1.4, 0.005, 0.35]),
                materials: [paint]
            )
            box.position = [0, 0.005, -2.4 - Float(stripe) * 0.52]
            sceneRoot.addChild(box)
        }
    }

    private func addGround(width: Float, depth: Float, z: Float, material: SimpleMaterial) {
        let ground = ModelEntity(
            mesh: .generatePlane(width: width, depth: depth),
            materials: [material]
        )
        ground.position = [0, 0, z]
        sceneRoot.addChild(ground)
    }

    /// Placeholder built from primitives. When the generated USDZ lands, load it
    /// here instead and name its lamp meshes "redLamp" / "greenLamp" — `apply`
    /// only cares about those two references.
    private func buildTrafficLight() {
        let housing = SimpleMaterial(color: UIColor(white: 0.12, alpha: 1), isMetallic: false)

        let light = Entity()
        light.position = [1.4, 0, -2.0]

        let pole = ModelEntity(
            mesh: .generateCylinder(height: 2.4, radius: 0.05),
            materials: [housing]
        )
        pole.position = [0, 1.2, 0]
        light.addChild(pole)

        let head = ModelEntity(
            mesh: .generateBox(size: [0.3, 0.62, 0.22], cornerRadius: 0.03),
            materials: [housing]
        )
        head.position = [0, 2.5, 0]
        light.addChild(head)

        let red = ModelEntity(mesh: .generateSphere(radius: 0.09), materials: [lampOff])
        red.name = "redLamp"
        red.position = [0, 2.63, 0.09]
        light.addChild(red)
        redLamp = red

        let green = ModelEntity(mesh: .generateSphere(radius: 0.09), materials: [lampOff])
        green.name = "greenLamp"
        green.position = [0, 2.37, 0.09]
        light.addChild(green)
        greenLamp = green

        sceneRoot.addChild(light)
    }

    private func buildBakery(sign: Entity?) {
        let wall = SimpleMaterial(color: UIColor(red: 0.85, green: 0.72, blue: 0.55, alpha: 1), isMetallic: false)
        let door = SimpleMaterial(color: UIColor(red: 0.45, green: 0.30, blue: 0.18, alpha: 1), isMetallic: false)

        let shop = ModelEntity(mesh: .generateBox(size: [2.6, 2.8, 0.3]), materials: [wall])
        shop.position = [1.3, 1.4, -8.3]
        sceneRoot.addChild(shop)

        let shopDoor = ModelEntity(mesh: .generateBox(size: [0.9, 2.0, 0.06]), materials: [door])
        shopDoor.position = [1.3, 1.0, -8.12]
        sceneRoot.addChild(shopDoor)

        if let sign {
            sign.position = [1.3, 2.55, -8.1]
            sceneRoot.addChild(sign)
        }
    }

    private func buildWaypoints() {
        for (index, position) in Self.waypointPositions.enumerated() {
            let disc = ModelEntity(
                mesh: .generateCylinder(height: 0.02, radius: 0.24),
                materials: [waypointActive]
            )
            disc.name = "waypoint-\(index)"
            disc.position = [position.x, 0.02, position.z]
            disc.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.35)]))
            disc.components.set(InputTargetComponent())
            disc.components.set(HoverEffectComponent())
            sceneRoot.addChild(disc)
            waypoints.append(disc)
        }
    }
}

struct WayfindingSpaceView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var controller = WayfindingSceneController()
    @State private var isWalking = false

    var body: some View {
        RealityView { content, attachments in
            controller.install(in: content, attachments: attachments)
            if let prompt = attachments.entity(for: "prompt") {
                prompt.position = [0, 1.7, -1.2]
                content.add(prompt)
            }
            appModel.wayfinding.begin()
            controller.apply(appModel.wayfinding)
        } update: { _, _ in
            controller.apply(appModel.wayfinding)
        } attachments: {
            Attachment(id: "prompt") {
                Text(promptText)
                    .font(.extraLargeTitle)
                    .multilineTextAlignment(.center)
                    .padding(36)
                    .glassBackgroundEffect()
            }
            Attachment(id: "bakerySign") {
                Text("Bakery")
                    .font(.extraLargeTitle)
                    .padding(24)
                    .glassBackgroundEffect()
            }
        }
        .gesture(
            TapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    handleTap(value.entity)
                }
        )
        .onDisappear {
            appModel.wayfinding.stop()
            if appModel.phase == .inActivity {
                appModel.phase = .welcome
            }
        }
    }

    private var promptText: String {
        let exercise = appModel.wayfinding
        if exercise.isFinished {
            return "You made it to the bakery!"
        }
        switch exercise.nextWaypoint {
        case 0:
            return "Let's walk to the bakery.\nTouch the glowing circle to walk."
        case WayfindingExercise.crossingWaypointIndex:
            return exercise.lightState == .red
                ? "Wait for the green light."
                : "It's green — you can cross now."
        default:
            return "Nearly there. The bakery is just ahead."
        }
    }

    private func handleTap(_ entity: Entity) {
        guard !isWalking, let index = controller.waypointIndex(of: entity) else { return }
        if appModel.wayfinding.tappedWaypoint(index) == .walk {
            Task { await walk(to: index) }
        }
    }

    private func walk(to index: Int) async {
        isWalking = true
        await controller.fadeScene(to: 0, over: 0.3)
        controller.moveUser(toWaypoint: index)
        appModel.wayfinding.arrived(at: index)
        await controller.fadeScene(to: 1, over: 0.3)
        isWalking = false

        if appModel.wayfinding.isFinished {
            try? await Task.sleep(for: .seconds(3))
            appModel.phase = .finished
            await dismissImmersiveSpace()
        }
    }
}
