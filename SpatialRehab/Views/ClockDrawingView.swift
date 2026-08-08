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

    @State private var strokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []
    @State private var saveErrorMessage: String?

    private let canvasSize: CGFloat = 400

    var body: some View {
        VStack(spacing: 20) {
            Text(BaselineAssessmentContent.ClockDrawing.promptText)
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
        Canvas { context, _ in
            for stroke in strokes + [currentStroke] {
                guard stroke.count > 1 else { continue }
                var path = Path()
                path.addLines(stroke)
                context.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
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

        let fileName = "baseline-clock-\(Int(Date.now.timeIntervalSince1970)).png"
        let fileURL = URL.documentsDirectory.appending(path: fileName)

        do {
            try pngData.write(to: fileURL)
        } catch {
            saveErrorMessage = "Couldn't save the drawing. Please try again."
            return
        }

        onComplete(ClockDrawingResult(imageFileName: fileName, capturedAt: .now, score: nil))
    }
}

#Preview(windowStyle: .automatic) {
    ClockDrawingView(onComplete: { _ in })
}
