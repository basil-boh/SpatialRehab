import SwiftUI
import UIKit

/// The clock-drawing baseline game: free-draw on a plain canvas, no auto-scoring.
///
/// Deliberately unscored (see `ClockDrawingResult`) — only the rasterized sketch is kept
/// for a caregiver to review later. "Clear" resets freely with no penalty, matching
/// errorless-learning intent elsewhere in this app. Plain SwiftUI `Canvas` + `DragGesture`
/// is used because `.skills/spatial-swiftui-developer` has no visionOS-specific drawing API
/// — this is the idiomatic choice, not a workaround. See `Docs/BaselineAssessment_Design.md`.
struct ClockDrawingView: View {
    let onComplete: (ClockDrawingResult) -> Void

    /// Default reproduces the original baseline clock prompt exactly (free-recall, no
    /// outline), so the existing call site (`ClockDrawingView(onComplete:)`) is unchanged.
    /// Daily Practice passes a level-driven subject instead — see `DrawingSubjects`.
    var subject: DrawingSubject = DrawingSubjects.all[0]

    /// How visible the traceable outline is. Default matches the original fixed 0.25 used
    /// before this was configurable. Daily Practice fades this across repeat cycles of the
    /// subject list ("vanishing cues") — see `DrawingSubjects.outlineOpacity(forLevel:)`.
    /// This view itself stays unaware of "levels"; it just renders whatever opacity it's
    /// given, same as it stays unaware of what `subject` means beyond its two fields.
    var outlineOpacity: Double = 0.25

    @State private var strokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []
    @State private var saveErrorMessage: String?

    private let canvasSize: CGFloat = 400

    var body: some View {
        VStack(spacing: 20) {
            Text(subject.promptText)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)

            canvas
                .frame(width: canvasSize, height: canvasSize)
                .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .gesture(drawingGesture)

            HStack(spacing: 16) {
                Button("Clear") {
                    strokes = []
                    currentStroke = []
                }
                .buttonStyle(.bordered)

                Button("Done") {
                    saveDrawing()
                }
                .font(.title3.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            // Surfaced rather than silently dropped, matching ContentView's convention for
            // openImmersiveSpace failures.
            if let saveErrorMessage {
                VStack(spacing: 8) {
                    Text(saveErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    Button("Try Again") { saveDrawing() }
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var canvas: some View {
        ZStack {
            // Faint traceable guide for every subject except the clock (kept free-recall,
            // matching the standard Clock Drawing Test format). Baked into the saved PNG
            // along with the strokes, so a later reviewer sees what was traced, not just the
            // marks — see `ClockDrawingResult.subjectID` for the same info in text form.
            if let outlineSymbolName = subject.outlineSymbolName {
                Image(systemName: outlineSymbolName)
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.gray.opacity(outlineOpacity))
                    .padding(60)
                    .allowsHitTesting(false)
            }

            Canvas { context, _ in
                for stroke in strokes + [currentStroke] {
                    guard stroke.count > 1 else { continue }
                    var path = Path()
                    path.addLines(stroke)
                    context.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }

    private var drawingGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                currentStroke.append(value.location)
            }
            .onEnded { _ in
                if currentStroke.count > 1 {
                    strokes.append(currentStroke)
                }
                currentStroke = []
            }
    }

    @MainActor
    private func saveDrawing() {
        saveErrorMessage = nil

        let renderer = ImageRenderer(content: canvas.frame(width: canvasSize, height: canvasSize).background(.white))
        renderer.scale = 2

        guard let uiImage = renderer.uiImage, let pngData = uiImage.pngData() else {
            saveErrorMessage = "Couldn't capture the drawing. Please try again."
            return
        }

        // Prefix kept generic (not "baseline-") — this view is now also used repeatedly from
        // Daily Practice, not just the one-time baseline battery.
        let fileName = "\(subject.id)-drawing-\(Int(Date.now.timeIntervalSince1970)).png"
        let fileURL = URL.documentsDirectory.appending(path: fileName)

        do {
            try pngData.write(to: fileURL)
        } catch {
            saveErrorMessage = "Couldn't save the drawing. Please try again."
            return
        }

        onComplete(ClockDrawingResult(imageFileName: fileName, capturedAt: .now, subjectID: subject.id, score: nil))
    }
}

#Preview(windowStyle: .automatic) {
    ClockDrawingView(onComplete: { _ in })
}
