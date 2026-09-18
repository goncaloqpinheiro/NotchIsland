import Foundation

/// Decides whether a browser is playing from two signals: its audio output
/// (reliable, but lingers about 10 s after a pause) and its media power
/// assertions (released about 2 s after the page goes quiet). Assertions only
/// count once the browser has been seen taking one while making sound, so a
/// browser that never takes them still works from audio output alone.
struct BrowserPlayback: Equatable {
    private var sawAssertionWhileSounding = false

    mutating func isPlaying(makingSound: Bool, holdsMediaAssertion: Bool) -> Bool {
        guard makingSound else {
            sawAssertionWhileSounding = false
            return false
        }
        if holdsMediaAssertion {
            sawAssertionWhileSounding = true
        }
        return holdsMediaAssertion || !sawAssertionWhileSounding
    }
}
