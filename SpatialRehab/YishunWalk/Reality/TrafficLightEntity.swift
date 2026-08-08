import RealityKit
import UIKit

/// Procedural placeholder traffic light (swap for USDZ with matching child names later).
@MainActor
final class TrafficLightEntity: Entity {
    private(set) var currentState: TrafficLightState = .red

    private var redLight: ModelEntity?
    private var yellowLight: ModelEntity?
    private var greenLight: ModelEntity?

    required init() {
        super.init()
        name = "TrafficLight"
        buildPlaceholder()
        updateLightState(.red)
    }

    func updateLightState(_ state: TrafficLightState) {
        currentState = state
        redLight?.model?.materials = [Self.bulbMaterial(isActive: state == .red, color: .systemRed)]
        yellowLight?.model?.materials = [Self.bulbMaterial(isActive: state == .yellow, color: .systemYellow)]
        greenLight?.model?.materials = [Self.bulbMaterial(isActive: state == .green, color: .systemGreen)]
    }

    private func buildPlaceholder() {
        // Post
        let postMesh = MeshResource.generateCylinder(height: 0.55, radius: 0.03)
        var postMaterial = PhysicallyBasedMaterial()
        postMaterial.baseColor = .init(tint: UIColor.darkGray)
        postMaterial.roughness = 0.7
        let post = ModelEntity(mesh: postMesh, materials: [postMaterial])
        post.name = "Post"
        post.position = [0, 0.275, 0]
        addChild(post)

        // Housing
        let housingMesh = MeshResource.generateBox(width: 0.14, height: 0.36, depth: 0.1, cornerRadius: 0.02)
        var housingMaterial = PhysicallyBasedMaterial()
        housingMaterial.baseColor = .init(tint: UIColor(white: 0.12, alpha: 1))
        housingMaterial.roughness = 0.45
        let housing = ModelEntity(mesh: housingMesh, materials: [housingMaterial])
        housing.name = "Housing"
        housing.position = [0, 0.62, 0]
        addChild(housing)

        redLight = makeBulb(name: "RedLight", y: 0.12)
        yellowLight = makeBulb(name: "YellowLight", y: 0)
        greenLight = makeBulb(name: "GreenLight", y: -0.12)

        if let redLight { housing.addChild(redLight) }
        if let yellowLight { housing.addChild(yellowLight) }
        if let greenLight { housing.addChild(greenLight) }

        // Base plate for downward-gaze cue
        let baseMesh = MeshResource.generateBox(width: 0.22, height: 0.02, depth: 0.22, cornerRadius: 0.02)
        var baseMaterial = PhysicallyBasedMaterial()
        baseMaterial.baseColor = .init(tint: UIColor.darkGray)
        let base = ModelEntity(mesh: baseMesh, materials: [baseMaterial])
        base.name = "Base"
        base.position = [0, 0.01, 0]
        addChild(base)
    }

    private func makeBulb(name: String, y: Float) -> ModelEntity {
        let mesh = MeshResource.generateSphere(radius: 0.04)
        let entity = ModelEntity(mesh: mesh, materials: [Self.bulbMaterial(isActive: false, color: .gray)])
        entity.name = name
        entity.position = [0, y, 0.06]
        return entity
    }

    private static func bulbMaterial(isActive: Bool, color: UIColor) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        if isActive {
            material.baseColor = .init(tint: color)
            material.emissiveColor = .init(color: color)
            material.emissiveIntensity = 2.5
            material.roughness = 0.3
        } else {
            material.baseColor = .init(tint: color.withAlphaComponent(0.25))
            material.emissiveColor = .init(color: .black)
            material.emissiveIntensity = 0
            material.roughness = 0.8
        }
        return material
    }
}
