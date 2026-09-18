import Foundation

/// Playback actions the island's views can trigger.
struct NowPlayingActions {
    var togglePlayPause: () -> Void = {}
    var next: () -> Void = {}
    var previous: () -> Void = {}
    var seek: (TimeInterval) -> Void = { _ in }
    var openPlayer: () -> Void = {}
    var openAutomationSettings: () -> Void = {}
}
