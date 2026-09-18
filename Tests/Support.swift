import AppKit

/// A small test runner: plain checks grouped in sections, so the suite builds
/// and runs with only the Command Line Tools (no Xcode, no XCTest).
@MainActor
enum Checks {
    static var passed = 0
    static var failed = 0
    static let verbose = CommandLine.arguments.contains("--verbose")
    fileprivate static var sectionFailures: [String] = []
}

@MainActor
func check(_ name: String, _ condition: Bool) {
    if condition {
        Checks.passed += 1
        if Checks.verbose { print("    ok    \(name)") }
    } else {
        Checks.failed += 1
        Checks.sectionFailures.append(name)
        if Checks.verbose { print("    FAIL  \(name)") }
    }
}

/// Something worth knowing about this Mac, shown with --verbose.
@MainActor
func info(_ text: String) {
    if Checks.verbose { print("    info  \(text)") }
}

/// Runs one group of checks and prints how it went.
@MainActor
func section(_ name: String, _ body: @MainActor () async -> Void) async {
    let before = (passed: Checks.passed, failed: Checks.failed)
    Checks.sectionFailures = []
    if Checks.verbose { print(name) }
    await body()
    let passed = Checks.passed - before.passed
    let failed = Checks.failed - before.failed
    let label = name.padding(toLength: 28, withPad: " ", startingAt: 0)
    if failed == 0 {
        print("\(label)\(passed) passed")
    } else {
        print("\(label)\(failed) of \(passed + failed) FAILED")
        for failure in Checks.sectionFailures { print("    FAIL  \(failure)") }
    }
}

func wait(_ seconds: Double) async {
    try? await Task.sleep(for: .seconds(seconds))
}

@MainActor
func makeModel(_ name: String) -> (NotchViewModel, NowPlayingModel, TimerModel, AppSettings) {
    let settings = AppSettings(defaults: ScratchDefaults.make(name))
    settings.playsSounds = false
    let nowPlaying = NowPlayingModel()
    let timer = TimerModel()
    let model = NotchViewModel(settings: settings, nowPlaying: nowPlaying, timer: timer)
    model.detectedNotchSize = CGSize(width: 156, height: 28)
    return (model, nowPlaying, timer, settings)
}

@MainActor
func play(_ nowPlaying: NowPlayingModel) {
    nowPlaying.apply(source: .app(.spotify), snapshot: PlayerSnapshot(isPlaying: true, title: "Song", artist: "A", album: "",
        duration: 100, position: 0, capturedAt: .now, trackID: "1"))
}
