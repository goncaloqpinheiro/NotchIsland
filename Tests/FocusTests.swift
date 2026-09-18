import AppKit

@MainActor
func testFocus() async {
    let assertions = """
    {"data":[{"storeAssertionRecords":[
      {"assertionUUID":"A","assertionStartDateTimestamp":700000000,"assertionDetails":{"assertionDetailsModeIdentifier":"com.apple.donotdisturb.mode.default"}},
      {"assertionUUID":"B","assertionStartDateTimestamp":710000000.5,"assertionDetails":{"assertionDetailsModeIdentifier":"com.apple.focus.work"}}
    ]}],"header":{"timestamp":1}}
    """.data(using: .utf8)!
    let configurations = """
    {"data":[{"modeConfigurations":{
      "com.apple.focus.work":{"mode":{"name":"Deep Work","symbolImageName":"briefcase.fill","tintColorName":"systemOrangeColor","modeIdentifier":"com.apple.focus.work"}},
      "custom.one":{"mode":{"name":"Studying","symbolImageName":"not.a.real.symbol"}}
    }}]}
    """.data(using: .utf8)!

    check("the newest assertion is the active Focus", FocusDatabase.activeModeIdentifier(in: assertions) == "com.apple.focus.work")
    let work = FocusDatabase.activeMode(assertions: assertions, configurations: configurations)
    check("name, symbol and color come from the configuration",
          work == FocusMode(identifier: "com.apple.focus.work", name: "Deep Work", symbol: "briefcase.fill", tintName: "systemOrangeColor"))
    let custom = FocusDatabase.mode("custom.one", in: configurations)
    check("an unknown symbol falls back", custom.name == "Studying" && custom.symbol == "moon.fill" && custom.tint == .indigo)
    let unconfigured = FocusDatabase.mode("com.apple.sleep.sleep-mode", in: nil)
    check("built-in details when the configuration is missing", unconfigured.name == "Sleep" && unconfigured.symbol == "bed.double.fill")
    check("no assertions means no Focus", FocusDatabase.activeMode(assertions: #"{"data":[{}],"header":{}}"#.data(using: .utf8), configurations: configurations) == nil)
    check("missing or broken files mean no Focus", FocusDatabase.activeMode(assertions: nil, configurations: nil) == nil
          && FocusDatabase.activeMode(assertions: Data("nope".utf8), configurations: nil) == nil)
    let builtIns = ["com.apple.donotdisturb.mode.default", "com.apple.sleep.sleep-mode", "com.apple.donotdisturb.mode.driving",
                    "com.apple.focus.personal-time", "com.apple.focus.work", "com.apple.donotdisturb.mode.workout",
                    "com.apple.focus.gaming", "com.apple.focus.mindfulness", "com.apple.focus.reading",
                    "com.apple.focus.reduce-interruptions", "something.else"]
    check("every built-in symbol exists on this Mac", builtIns.allSatisfy {
        NSImage(systemSymbolName: FocusMode.builtIn($0).symbol, accessibilityDescription: nil) != nil })
    check("colors from system color names", FocusMode.builtIn("com.apple.focus.work").tint == .teal
          && FocusMode(identifier: "x", name: "x", symbol: "x", tintName: "systemPinkColor").tint == .pink)

    // The Focus folder needs Full Disk Access, which the terminal running these
    // tests may or may not have. Either way, the app must see it the same way.
    let hasAccess: Bool
    do {
        _ = try Data(contentsOf: FocusDatabase.directory.appending(path: "Assertions.json"))
        hasAccess = true
    } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
        hasAccess = true
    } catch {
        hasAccess = false
    }
    info(hasAccess ? "this process can read the Focus files" : "this process can't read the Focus files")
    switch FocusDatabase.activeMode() {
    case .failure: check("a denied read of the Focus files is reported as denied", !hasAccess)
    case .success: check("an allowed read of the Focus files succeeds", hasAccess)
    }

    let (model, _, _, settings) = makeModel("focus")
    let sounds = SoundPlayer(settings: settings)
    let alerts = AlertController(model: model, settings: settings, sounds: sounds)
    let focus = FocusController(model: model, settings: settings, alerts: alerts)
    model.isFocusAccessGranted = !hasAccess
    focus.start()
    check("the controller knows whether it has access", model.isFocusAccessGranted == hasAccess)

    alerts.present(.focus(FocusAlert(mode: .builtIn("com.apple.donotdisturb.mode.default"), isOn: true)), for: 0.4)
    check("a Focus alert is a pill beside the notch", model.resting == .focus && model.restingSize.height == model.notchSize.height)
    let compact = CGSize(width: model.notchSize.width + 2 * NotchStyle.focusEarWidth, height: model.notchSize.height)
    check("the Focus pill is compact: symbol and On/Off only", model.restingSize == compact
          && NotchStyle.focusEarWidth < NotchStyle.hudEarWidth)
    model.alert = .focus(FocusAlert(mode: .builtIn("com.apple.focus.reduce-interruptions"), isOn: true))
    check("a long Focus name doesn't change its size", model.restingSize == compact)
    await wait(0.6)
    check("the alert hides after its duration", model.alert == nil)

    // The FSEvents watcher, on a scratch folder.
    let folder = FileManager.default.temporaryDirectory.appending(path: "NotchIslandTests-watch-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let watcher = DirectoryWatcher(url: folder, fileNames: FocusDatabase.fileNames)
    var changes = 0
    var changedNames: Set<String> = []
    watcher.onChange = { names in
        changes += 1
        changedNames.formUnion(names)
    }
    watcher.start()
    await wait(0.5)
    try? Data("{}".utf8).write(to: folder.appending(path: "Metrics.json"), options: .atomic)
    try? Data("x".utf8).write(to: folder.appending(path: "Settings.sqlite-wal"))
    await wait(1.0)
    check("changes to other files in the folder are ignored", changes == 0)
    try? Data("{}".utf8).write(to: folder.appending(path: "Assertions.json"), options: .atomic)
    for _ in 0..<30 where changes == 0 { await wait(0.1) }
    check("the folder watcher reports a replaced Focus file, by name", changes > 0 && changedNames == ["Assertions.json"])
    watcher.stop()
    let before = changes
    try? Data("{}".utf8).write(to: folder.appending(path: "Assertions.json"), options: .atomic)
    await wait(1.0)
    check("a stopped watcher stays quiet", changes == before)
}
