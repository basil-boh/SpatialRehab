import SwiftUI
import RealityKit
import UIKit

/// The immersive-space content for a guided task: anchors placeholder object markers to a
/// detected tabletop and highlights only the one relevant to the current step.
///
/// Errorless-learning intent (see `Docs/TaskDesign_MakingTea.md`): every marker except the
/// current step's target is fully hidden (`isEnabled = false`), not just dimmed, so there is
/// never more than one thing competing for attention.
///
/// Known gap: markers sit at fixed offsets from the table anchor (`MarkerLayout`) — there is
/// no drag-to-reposition yet, so they will not line up with a real kettle/cup unless the
/// person's table happens to match the assumed layout. Flagged in the design doc; a natural
/// next slice is a one-time "drag each marker onto your real object" calibration step.
struct ImmersiveTaskView: View {
    @ObservedObject var session: TaskSession

    /// Distance (meters) from a fingertip to the active marker that counts as "reached
    /// for it." Generous on purpose — see class doc on `HandProximityTracker`.
    private static let autoAdvanceDistance: Float = 0.12

    @State private var kettleMarker: ModelEntity?
    @State private var cupMarker: ModelEntity?
    @StateObject private var handTracker = HandProximityTracker()
    @State private var autoAdvancedStepID: String?

    var body: some View {
        RealityView { content, attachments in
            let tableAnchor = AnchorEntity(
                plane: .horizontal,
                classification: .table,
                minimumBounds: SIMD2<Float>(0.2, 0.2)
            )

            let kettle = Self.makeMarker(
                color: .systemCyan,
                mesh: .generateBox(size: SIMD3<Float>(0.08, 0.14, 0.08), cornerRadius: 0.015)
            )
            kettle.position = MarkerLayout.offsets[.kettle] ?? .zero
            kettle.isEnabled = false
            tableAnchor.addChild(kettle)

            let cup = Self.makeMarker(
                color: .systemOrange,
                mesh: .generateCylinder(height: 0.08, radius: 0.04)
            )
            cup.position = MarkerLayout.offsets[.cup] ?? .zero
            cup.isEnabled = false
            tableAnchor.addChild(cup)

            content.add(tableAnchor)

            kettleMarker = kettle
            cupMarker = cup
        } update: { _, attachments in
            updateActiveMarker(using: attachments)
        } attachments: {
            Attachment(id: "stepLabel") {
                Text(session.isComplete ? "Done" : session.currentStep.title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
            }
        }
        .task { handTracker.start() }
        .onDisappear { handTracker.stop() }
        .onChange(of: handTracker.nearestHandDistance) { _, distance in
            considerAutoAdvance(handDistance: distance)
        }
    }

    private static func makeMarker(color: UIColor, mesh: MeshResource) -> ModelEntity {
        let material = SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)
        return ModelEntity(mesh: mesh, materials: [material])
    }

    /// Shows only the marker for the current step's target object, and parks the floating
    /// text label just above it.
    private func updateActiveMarker(using attachments: RealityViewAttachments) {
        guard !session.isComplete else {
            kettleMarker?.isEnabled = false
            cupMarker?.isEnabled = false
            return
        }

        let activeObject = session.currentStep.markerObject
        kettleMarker?.isEnabled = (activeObject == .kettle)
        cupMarker?.isEnabled = (activeObject == .cup)

        let activeMarker = activeObject == .kettle ? kettleMarker : cupMarker
        handTracker.targetWorldPosition = activeMarker?.position(relativeTo: nil)

        guard let label = attachments.entity(for: "stepLabel") else { return }
        guard let activeMarker else { return }

        if label.parent !== activeMarker {
            activeMarker.addChild(label)
        }
        label.position = SIMD3<Float>(0, 0.10, 0)
    }

    /// Advances the step when a hand reaches close enough to the active marker. Latched per
    /// step (`autoAdvancedStepID`) so a hand that lingers near the target doesn't fire
    /// `advance()` repeatedly. The manual "Done" button in `GuidanceCardView` always still
    /// works — this is an additional way to complete a step, not a replacement.
    private func considerAutoAdvance(handDistance: Float?) {
        guard !session.isComplete,
              let handDistance,
              handDistance < Self.autoAdvanceDistance,
              autoAdvancedStepID != session.currentStep.id
        else { return }

        autoAdvancedStepID = session.currentStep.id
        session.advance()
    }
}
