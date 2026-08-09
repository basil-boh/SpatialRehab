import Foundation

/// Singapore Mahjong rules engine (SG148 set): tile taxonomy, real win
/// evaluation (four sets — chows/pongs — plus one eye), winning-tile search,
/// and a gentle discard heuristic. Pure logic, no UI.
enum MahjongRules {
    enum Suit: String, CaseIterable {
        case bamboo, dots, char
    }

    enum TileKind: Equatable {
        case suited(Suit, Int)
        case honor
        case bonus
    }

    static func kind(of face: String) -> TileKind {
        for suit in Suit.allCases where face.hasPrefix("\(suit.rawValue)_") {
            if let rank = Int(face.dropFirst(suit.rawValue.count + 1)) {
                return .suited(suit, rank)
            }
        }
        if face.hasPrefix("dragon_") || face.hasPrefix("wind_") {
            return .honor
        }
        return .bonus
    }

    static func isBonus(_ face: String) -> Bool {
        if case .bonus = kind(of: face) { return true }
        return false
    }

    static func faceName(_ suit: Suit, _ rank: Int) -> String {
        "\(suit.rawValue)_\(rank)"
    }

    /// All playable face types (suits + honors), for winning-tile search.
    static let allPlayableFaces: [String] = {
        var faces: [String] = []
        for suit in Suit.allCases {
            for rank in 1...9 {
                faces.append(faceName(suit, rank))
            }
        }
        faces += ["dragon_red", "dragon_green", "dragon_white",
                  "wind_east", "wind_south", "wind_west", "wind_north"]
        return faces
    }()

    /// True when `faces` (the concealed tiles including the tile just drawn
    /// or claimed) plus `exposedSets` completed melds form a valid Mahjong:
    /// (4 − exposedSets) sets + one eye.
    static func isWinningHand(_ faces: [String], exposedSets: Int) -> Bool {
        let setsNeeded = 4 - exposedSets
        guard faces.count == setsNeeded * 3 + 2 else { return false }
        var counts: [String: Int] = [:]
        for face in faces {
            if isBonus(face) { return false }
            counts[face, default: 0] += 1
        }
        for eye in counts.keys where counts[eye, default: 0] >= 2 {
            counts[eye]! -= 2
            if canFormSets(&counts, setsNeeded: setsNeeded) {
                counts[eye]! += 2
                return true
            }
            counts[eye]! += 2
        }
        return false
    }

    private static func canFormSets(_ counts: inout [String: Int], setsNeeded: Int) -> Bool {
        guard let face = allPlayableFaces.first(where: { counts[$0, default: 0] > 0 }) else {
            return setsNeeded == 0
        }
        if setsNeeded == 0 { return false }

        if counts[face, default: 0] >= 3 {
            counts[face]! -= 3
            let ok = canFormSets(&counts, setsNeeded: setsNeeded - 1)
            counts[face]! += 3
            if ok { return true }
        }
        if case .suited(let suit, let rank) = kind(of: face), rank <= 7 {
            let second = faceName(suit, rank + 1)
            let third = faceName(suit, rank + 2)
            if counts[second, default: 0] > 0, counts[third, default: 0] > 0 {
                counts[face]! -= 1
                counts[second]! -= 1
                counts[third]! -= 1
                let ok = canFormSets(&counts, setsNeeded: setsNeeded - 1)
                counts[face]! += 1
                counts[second]! += 1
                counts[third]! += 1
                if ok { return true }
            }
        }
        return false
    }

    /// Faces that would complete the hand if drawn or claimed.
    static func winningFaces(concealed: [String], exposedSets: Int) -> Set<String> {
        var result: Set<String> = []
        for candidate in allPlayableFaces {
            if isWinningHand(concealed + [candidate], exposedSets: exposedSets) {
                result.insert(candidate)
            }
        }
        return result
    }

    /// Chow options for a claimed discard: pairs of faces from the hand that
    /// complete a run with it.
    static func chowOptions(for discard: String, in hand: [String]) -> [[String]] {
        guard case .suited(let suit, let rank) = kind(of: discard) else { return [] }
        var options: [[String]] = []
        let has: (Int) -> Bool = { r in
            r >= 1 && r <= 9 && hand.contains(faceName(suit, r))
        }
        if has(rank - 2), has(rank - 1) {
            options.append([faceName(suit, rank - 2), faceName(suit, rank - 1)])
        }
        if has(rank - 1), has(rank + 1) {
            options.append([faceName(suit, rank - 1), faceName(suit, rank + 1)])
        }
        if has(rank + 1), has(rank + 2) {
            options.append([faceName(suit, rank + 1), faceName(suit, rank + 2)])
        }
        return options
    }

    /// The loneliest tile — safest to throw without hurting the hand.
    static func suggestedDiscard(from hand: [String]) -> String? {
        var counts: [String: Int] = [:]
        for face in hand {
            counts[face, default: 0] += 1
        }
        func score(_ face: String) -> Int {
            var value = (counts[face, default: 1] - 1) * 6
            if case .suited(let suit, let rank) = kind(of: face) {
                for delta in [-2, -1, 1, 2] {
                    let neighbor = rank + delta
                    if neighbor >= 1, neighbor <= 9,
                       counts[faceName(suit, neighbor), default: 0] > 0 {
                        value += abs(delta) == 1 ? 3 : 1
                    }
                }
            }
            return value
        }
        return hand.min { score($0) < score($1) }
    }
}
