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
        case closed
        case presenting
        case open
        case puttingAway
    }

    var phase: Phase = .closed
    var cardSide: CardSide = .face
    var isCardWindowOpen = false

    /// Relative currently playing a greeting (auto-clears when done).
    var playingMemberID: FamilyMember.ID?
    var videoProgress: Double = 0

    var owner: FamilyMember { DemoPersona.owner }

    var playingMember: FamilyMember? {
        guard let playingMemberID else { return nil }
        return DemoPersona.member(id: playingMemberID)
    }

    // MARK: - Presenting

    /// Shows the name card — tappable at any time, no ritual gating it.
    func present() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
            phase = .presenting
            cardSide = .face
            playingMemberID = nil
            isCardWindowOpen = true
        }
        // Settle out of the presenting bounce after its beat.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeInOut(duration: 0.55)) {
                phase = .open
            }
        }
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
        }
    }

    /// Every relative plays their greeting beat — the grandson is always visible in the
    /// tree now, so Mei Ling no longer doubles as his expand/collapse toggle.
    func selectMember(_ member: FamilyMember) {
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
            playingMemberID = nil
            cardSide = .face
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.easeOut(duration: 0.4)) {
                isCardWindowOpen = false
                phase = .closed
            }
        }
    }
}
