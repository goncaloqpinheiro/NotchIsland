import Foundation

/// How the lock shows while the screen is locked, and when it unlocks.
enum LockStyle: String, CaseIterable, Identifiable, Sendable {
    /// Below the camera housing first, then into the ear on its left; on unlock
    /// back to the center to open, then left again before tucking away.
    case centered
    /// Straight into the ear on the left and opens there, like Alcove.
    case side

    var id: String { rawValue }

    var name: String {
        switch self {
        case .centered: "Center, Then Side"
        case .side: "Side Only"
        }
    }
}
