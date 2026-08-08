import RealityKit
import UIKit

/// Builds a simple first-person VR corridor representing the Yishun walk.
@MainActor
enum ImmersivePathWorld {
    static let worldRootName = "YishunVRWorld"
    static let floorName = "WalkFloor"
    static let destinationName = "DestinationHome"

    static func makeWorld(pathLength: Float) -> Entity {
        let root = Entity()
        root.name = worldRootName

        root.addChild(makeSky())
        root.addChild(makeGround(pathLength: pathLength))
        root.addChild(makeRoad(pathLength: pathLength))
        root.addChild(makeLaneMarkers(pathLength: pathLength))
        root.addChild(makeStartSign())
        root.addChild(makeDestination(atZ: pathLength))
        root.addChild(makeTrafficLights(pathLength: pathLength))
        root.addChild(makeSideTrees(pathLength: pathLength))

        // Pose is applied by ImmersiveWalkSpaceView from player position/yaw.
        root.position = .zero
        return root
    }

    // MARK: - Pieces

    private static func makeSky() -> Entity {
        let mesh = MeshResource.generateSphere(radius: 80)
        var material = UnlitMaterial(color: UIColor(red: 0.55, green: 0.75, blue: 0.95, alpha: 1))
        let sky = ModelEntity(mesh: mesh, materials: [material])
        sky.name = "Sky"
        sky.scale = [-1, 1, 1] // inward-facing
        return sky
    }

    private static func makeGround(pathLength: Float) -> Entity {
        let length = pathLength + 20
        let mesh = MeshResource.generateBox(width: 24, height: 0.05, depth: length)
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(red: 0.45, green: 0.62, blue: 0.38, alpha: 1))
        material.roughness = 0.95
        let ground = ModelEntity(mesh: mesh, materials: [material])
        ground.name = "Grass"
        ground.position = [0, -0.03, length / 2 - 4]
        return ground
    }

    private static func makeRoad(pathLength: Float) -> Entity {
        let length = pathLength + 8
        let mesh = MeshResource.generateBox(width: 3.2, height: 0.04, depth: length)
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(white: 0.28, alpha: 1))
        material.roughness = 0.85
        let road = ModelEntity(mesh: mesh, materials: [material])
        road.name = floorName
        road.position = [0, 0, length / 2 - 2]

        // Collision + input so drag gestures can target the road.
        road.components.set(InputTargetComponent())
        road.components.set(CollisionComponent(shapes: [.generateBox(width: 3.2, height: 0.1, depth: length)]))
        road.components.set(HoverEffectComponent())

        return road
    }

    private static func makeLaneMarkers(pathLength: Float) -> Entity {
        let parent = Entity()
        parent.name = "LaneMarkers"
        var z: Float = 2
        while z < pathLength {
            let dash = ModelEntity(
                mesh: .generateBox(width: 0.12, height: 0.02, depth: 0.7),
                materials: [UnlitMaterial(color: .white)]
            )
            dash.position = [0, 0.03, z]
            parent.addChild(dash)
            z += 2.4
        }
        return parent
    }

    private static func makeStartSign() -> Entity {
        let parent = Entity()
        parent.name = "Start"
        parent.position = [-1.4, 0, 0.5]

        let post = ModelEntity(
            mesh: .generateCylinder(height: 1.4, radius: 0.04),
            materials: [SimpleMaterial(color: .darkGray, isMetallic: false)]
        )
        post.position = [0, 0.7, 0]
        parent.addChild(post)

        let board = ModelEntity(
            mesh: .generateBox(width: 0.9, height: 0.45, depth: 0.05, cornerRadius: 0.04),
            materials: [UnlitMaterial(color: UIColor.systemTeal)]
        )
        board.position = [0, 1.35, 0]
        parent.addChild(board)
        return parent
    }

    private static func makeDestination(atZ z: Float) -> Entity {
        let parent = Entity()
        parent.name = destinationName
        parent.position = [0, 0, z]

        // Simple “home” block representing Block 343.
        var wall = PhysicallyBasedMaterial()
        wall.baseColor = .init(tint: UIColor(red: 0.85, green: 0.78, blue: 0.68, alpha: 1))
        wall.roughness = 0.7

        let building = ModelEntity(
            mesh: .generateBox(width: 4.5, height: 3.2, depth: 2.2, cornerRadius: 0.05),
            materials: [wall]
        )
        building.position = [0, 1.6, 1.2]
        parent.addChild(building)

        // Glowing arrival portal / door
        var doorMat = UnlitMaterial(color: UIColor.systemGreen.withAlphaComponent(0.85))
        let door = ModelEntity(
            mesh: .generateBox(width: 1.1, height: 2.1, depth: 0.08),
            materials: [doorMat]
        )
        door.name = "ArrivalDoor"
        door.position = [0, 1.05, 0.05]
        parent.addChild(door)

        // Ground ring cue (downward gaze friendly)
        var ringMat = UnlitMaterial(color: UIColor.systemGreen)
        let ring = ModelEntity(
            mesh: .generateCylinder(height: 0.03, radius: 1.4),
            materials: [ringMat]
        )
        ring.position = [0, 0.02, 0]
        parent.addChild(ring)

        // Floating beacon
        let beacon = ModelEntity(
            mesh: .generateSphere(radius: 0.18),
            materials: [UnlitMaterial(color: .systemYellow)]
        )
        beacon.position = [0, 3.6, 1.0]
        parent.addChild(beacon)

        return parent
    }

    private static func makeTrafficLights(pathLength: Float) -> Entity {
        let parent = Entity()
        parent.name = "TrafficLights"
        let fractions: [Float] = [0.28, 0.55, 0.78]
        let states: [TrafficLightState] = [.red, .green, .red]

        for (index, fraction) in fractions.enumerated() {
            let light = TrafficLightEntity()
            light.scale = SIMD3(repeating: 1.35)
            light.position = [1.7, 0, pathLength * fraction]
            light.updateLightState(states[index])
            parent.addChild(light)
        }
        return parent
    }

    private static func makeSideTrees(pathLength: Float) -> Entity {
        let parent = Entity()
        parent.name = "Trees"
        var z: Float = 3
        var side: Float = 1
        while z < pathLength - 2 {
            let tree = makeTree()
            tree.position = [side * 4.2, 0, z]
            parent.addChild(tree)
            z += 4.5
            side *= -1
        }
        return parent
    }

    private static func makeTree() -> Entity {
        let tree = Entity()
        let trunk = ModelEntity(
            mesh: .generateCylinder(height: 1.2, radius: 0.12),
            materials: [SimpleMaterial(color: UIColor.brown, isMetallic: false)]
        )
        trunk.position = [0, 0.6, 0]
        tree.addChild(trunk)

        let canopy = ModelEntity(
            mesh: .generateSphere(radius: 0.7),
            materials: [SimpleMaterial(color: UIColor(red: 0.2, green: 0.55, blue: 0.25, alpha: 1), isMetallic: false)]
        )
        canopy.position = [0, 1.5, 0]
        tree.addChild(canopy)
        return tree
    }
}
