import Foundation

struct Person: Identifiable {
    let id = UUID()
    let name: String
    let relationship: String
    let imageName: String
    let note: String
}

