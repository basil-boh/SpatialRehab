import Foundation
import Observation
import SwiftUI

/// Session state for the “Who am I?” name-card feature.
@MainActor
@Observable
final class WhoAmISessionModel {
    enum CardSide: Equatable {
        case face
        case tree
    }

    enum Phase: Equatable {
        case nest
        case drawing
        case presenting
        case resting
        case puttingAway
    }

    var phase: Phase = .nest
    var cardSide: CardSide = .face
    var isCardWindowOpen = false
    var glowProgress: Double = 0
    var showExpandedGrandchild = false

    /// Relative currently playing a greeting (auto-clears when done).
    var playingMemberID: FamilyMember.ID?
    var videoProgress: Double = 0

    /// Drawing path in normalized view coordinates (0...1).
    var drawPoints: [CGPoint] = []
    var lastCircleQuality: Double = 0

    var owner: FamilyMember { DemoPersona.owner }

    var playingMember: FamilyMember? {
        guard let playingMemberID else { return nil }
        return DemoPersona.member(id: playingMemberID)
    }

    // MARK: - Circle summon

    func beginStroke(at point: CGPoint) {
        guard phase == .nest || phase == .resting || phase == .drawing else { return }
        if phase == .resting || phase == .nest {
            phase = .drawing
        }
        drawPoints = [point]
        glowProgress = 0.05
    }

    func continueStroke(to point: CGPoint) {
        guard phase == .drawing else { return }
        if let last = drawPoints.last, hypot(last.x - point.x, last.y - point.y) < 0.004 {
            return
        }
        drawPoints.append(point)
        glowProgress = min(0.85, circleClosureHint(for: drawPoints))
    }

    func endStroke() {
        guard phase == .drawing else { return }
        let quality = evaluateCircle(drawPoints)
        lastCircleQuality = quality
        if quality >= 0.55 {
            completeSummon()
        } else {
            // Soft fail: keep nest, clear path, calm glow down.
            withAnimation(.easeOut(duration: 0.45)) {
                drawPoints = []
                glowProgress = 0
                phase = isCardWindowOpen ? .resting : .nest
            }
        }
    }

    func completeSummon() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
            phase = .presenting
            glowProgress = 1
            cardSide = .face
            showExpandedGrandchild = false
            playingMemberID = nil
            isCardWindowOpen = true
        }
        // Settle to resting after present beat.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeInOut(duration: 0.55)) {
                phase = .resting
                drawPoints = []
                glowProgress = 0.25
            }
        }
    }

    /// Simulator / accessibility: complete circle without drawing.
    func summonWithButton() {
        drawPoints = []
        completeSummon()
    }

    // MARK: - Card actions

    func flipToFamily() {
        withAnimation(.easeInOut(duration: 0.55)) {
            cardSide = .tree
            playingMemberID = nil
        }
    }

    func flipToFace() {
        withAnimation(.easeInOut(duration: 0.55)) {
            cardSide = .face
            playingMemberID = nil
            showExpandedGrandchild = false
        }
    }

    func selectMember(_ member: FamilyMember) {
        if member.id == DemoPersona.meiLingID {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                showExpandedGrandchild.toggle()
            }
            return
        }
        playGreeting(for: member)
    }

    func selectGrandchild(_ member: FamilyMember) {
        playGreeting(for: member)
    }

    func playGreeting(for member: FamilyMember) {
        guard member.hasGreetingVideo else {
            // Soft flash: no video yet — still show relation beat then clear.
            playingMemberID = member.id
            videoProgress = 0
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1600))
                if playingMemberID == member.id {
                    withAnimation(.easeOut(duration: 0.35)) {
                        playingMemberID = nil
                        videoProgress = 0
                    }
                }
            }
            return
        }

        playingMemberID = member.id
        videoProgress = 0

        if member.videoURL != nil {
            // Real video: the player calls finishGreeting when playback ends;
            // this is only a safety net if loading stalls.
            let id = member.id
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(30))
                finishGreeting(for: id)
            }
            return
        }

        let duration: Duration = .seconds(4)
        let steps = 40
        Task { @MainActor in
            for step in 1...steps {
                try? await Task.sleep(for: duration / steps)
                guard playingMemberID == member.id else { return }
                videoProgress = Double(step) / Double(steps)
            }
            withAnimation(.easeInOut(duration: 0.4)) {
                playingMemberID = nil
                videoProgress = 0
            }
        }
    }

    func finishGreeting(for id: FamilyMember.ID) {
        guard playingMemberID == id else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            playingMemberID = nil
            videoProgress = 0
        }
    }

    func putAway() {
        withAnimation(.easeInOut(duration: 0.65)) {
            phase = .puttingAway
            glowProgress = 0.9
            playingMemberID = nil
            cardSide = .face
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.easeOut(duration: 0.4)) {
                isCardWindowOpen = false
                phase = .nest
                glowProgress = 0
                drawPoints = []
                showExpandedGrandchild = false
            }
        }
    }

    // MARK: - Circle math (approx, dementia-friendly)

    /// 0...1 hint while drawing (how close start/end are + coverage).
    private func circleClosureHint(for points: [CGPoint]) -> Double {
        guard points.count >= 8, let first = points.first, let last = points.last else {
            return min(0.4, Double(points.count) / 40.0)
        }
        let close = 1.0 - min(1.0, hypot(first.x - last.x, first.y - last.y) / 0.35)
        let length = pathLength(points)
        return min(0.85, 0.2 + close * 0.4 + min(0.35, length / 2.5))
    }

    /// Quality score for finished stroke; ~0.55+ counts as a circle.
    private func evaluateCircle(_ points: [CGPoint]) -> Double {
        guard points.count >= 12 else { return 0 }
        guard let first = points.first, let last = points.last else { return 0 }

        let closure = hypot(first.x - last.x, first.y - last.y)
        let closureScore = max(0, 1.0 - closure / 0.28)

        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else { return 0 }
        let width = max(maxX - minX, 0.02)
        let height = max(maxY - minY, 0.02)
        let aspect = min(width, height) / max(width, height)
        let aspectScore = aspect // 1 = square-ish bounding box

        let cx = (minX + maxX) / 2
        let cy = (minY + maxY) / 2
        let radii = points.map { hypot($0.x - cx, $0.y - cy) }
        let meanR = radii.reduce(0, +) / Double(radii.count)
        guard meanR > 0.04 else { return 0 }
        let variance = radii.map { ($0 - meanR) * ($0 - meanR) }.reduce(0, +) / Double(radii.count)
        let cv = sqrt(variance) / meanR
        let roundScore = max(0, 1.0 - cv / 0.55)

        let length = pathLength(points)
        let circumference = 2 * Double.pi * meanR
        let lengthScore = max(0, 1.0 - abs(length - circumference) / max(circumference, 0.1))

        return (closureScore * 0.35) + (aspectScore * 0.2) + (roundScore * 0.3) + (lengthScore * 0.15)
    }

    private func pathLength(_ points: [CGPoint]) -> Double {
        guard points.count > 1 else { return 0 }
        var total = 0.0
        for i in 1..<points.count {
            total += hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y)
        }
        return total
    }
}
