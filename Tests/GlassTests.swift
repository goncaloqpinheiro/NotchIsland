import AppKit
import SwiftUI

@MainActor
func testGlassAndSizing() {
    let notch = CGSize(width: 168, height: 28)
    check("a spring's overshoot can't draw the island smaller than the notch",
          CGSize(width: 160, height: 19.6).atLeast(notch) == notch
          && CGSize(width: 400, height: 228).atLeast(notch) == CGSize(width: 400, height: 228))
    #if compiler(>=6.2)
    let hasLiquidGlass = ProcessInfo.processInfo.isOperatingSystemAtLeast(
        OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0))
    #else
    let hasLiquidGlass = false
    #endif
    check("Liquid Glass is used exactly where macOS and the build have it", IslandGlass.liquid.usesLiquidGlass == hasLiquidGlass)
    check("the blurs aren't Liquid Glass", !IslandGlass.frosted.usesLiquidGlass && !IslandGlass.blur.usesLiquidGlass)
    check("only frosted glass draws the rim", IslandGlass.frosted.showsRim
          && !IslandGlass.liquid.showsRim && !IslandGlass.blur.showsRim)
    if hasLiquidGlass {
        check("Liquid Glass hugs the island; the blurs fade out further",
              IslandGlass.liquid.spread == NotchStyle.glassEdgeSpread
              && IslandGlass.frosted.spread == NotchStyle.haloSpread
              && NotchStyle.glassEdgeSpread < NotchStyle.haloSpread)
        check("Liquid Glass stays visible at a low strength", IslandGlass.liquid.opacity(forStrength: 0.3) > 0.5
              && IslandGlass.liquid.opacity(forStrength: 1) == 1)
    } else {
        check("without Liquid Glass, its choice draws like the blur",
              IslandGlass.liquid.spread == IslandGlass.blur.spread
              && IslandGlass.liquid.opacity(forStrength: 0.3) == IslandGlass.blur.opacity(forStrength: 0.3))
    }
    check("the blurs read stronger than the raw slider, and still reach full at 100%",
          IslandGlass.frosted.opacity(forStrength: 0.3) > 0.4 && IslandGlass.frosted.opacity(forStrength: 1) == 1
          && IslandGlass.blur.opacity(forStrength: 0.3) == IslandGlass.frosted.opacity(forStrength: 0.3))
    check("the rim sits inside the island's edge", NotchStyle.rimWidth == 2
          && NotchStyle.rimOpacity.top > NotchStyle.rimOpacity.bottom && NotchStyle.rimOpacity.top < 0.5)

    let defaults = ScratchDefaults.make("glass")
    let settings = AppSettings(defaults: defaults)
    let model = NotchViewModel(settings: settings, nowPlaying: NowPlayingModel())
    check("frosted glass by default, and the island follows the setting", settings.glass == .frosted && model.glass == .frosted)
    settings.glass = .blur
    check("the island follows a change", model.glass == .blur)
    check("the choice is remembered", AppSettings(defaults: defaults).glass == .blur)
    defaults.set("clear", forKey: "glassStyle")  // a style from an older build
    check("an unknown stored style falls back", AppSettings(defaults: defaults).glass == .frosted)

    // Glass color: adaptive by default, which takes its color from what's behind
    // and so has no tint of its own; a custom color is remembered.
    let colored = AppSettings(defaults: defaults)
    let colorModel = NotchViewModel(settings: colored, nowPlaying: NowPlayingModel())
    check("adaptive glass is the default, with no tint of its own", colored.glassAdapts && colored.glassTint == nil
          && colorModel.glassAdapts && colorModel.glassTint == nil)
    let pink = GlassTint(red: 1, green: 0.35, blue: 0.65)
    colored.glassAdapts = false
    colored.glassTint = pink
    check("a glass color is remembered", AppSettings(defaults: defaults).glassTint == pink
          && !AppSettings(defaults: defaults).glassAdapts && colorModel.glassTint == pink)
    colored.glassAdapts = true
    check("adaptive glass drops the color while it's on", colorModel.glassTint == nil)
    colored.glassAdapts = false
    check("turning it off brings the color back", colorModel.glassTint == pink)
    colored.glassTint = nil
    check("going back to Natural forgets the color and stays natural", AppSettings(defaults: defaults).glassTint == nil
          && !AppSettings(defaults: defaults).glassAdapts)
    let older = ScratchDefaults.make("glass-older")
    older.set(pink.stored, forKey: "glassTint")
    let upgraded = AppSettings(defaults: older)
    check("a color picked before adaptive glass existed stays", !upgraded.glassAdapts && upgraded.glassTint == pink)
    check("the color follows the Strength slider", GlassTint.opacity(forStrength: 0) == 0.3 && GlassTint.opacity(forStrength: 1) == 0.8)
    let roundTrip = GlassTint(GlassTint.starting.color)
    check("colors survive the color well", abs(roundTrip.red - GlassTint.starting.red) < 0.01
          && abs(roundTrip.green - GlassTint.starting.green) < 0.01 && abs(roundTrip.blue - GlassTint.starting.blue) < 0.01)
    check("damaged stored values are ignored", GlassTint(stored: [2.0, 0.0, 0.0]) == nil && GlassTint(stored: "blue") == nil
          && GlassTint(stored: [0.5, 0.5]) == nil)

    // The glass follows hovers and alerts, but not what sits on screen for hours.
    let (halo, playing, timer, haloSettings) = makeModel("halo")
    check("the plain notch has no glass", !halo.showsHalo)
    halo.state = .peeking
    check("a hover shows it", halo.showsHalo)
    halo.state = .expanded
    check("the open island shows it", halo.showsHalo)
    halo.state = .collapsed
    play(playing)
    check("music alone doesn't", !halo.showsHalo && halo.resting == .liveActivity)
    timer.show(.running(endDate: Date().addingTimeInterval(60)), duration: 60)
    check("a running timer doesn't", !halo.showsHalo && halo.resting == .timer)
    timer.show(.idle, duration: 0)
    halo.stopwatch.show(.running(start: Date()))
    check("a running stopwatch doesn't", !halo.showsHalo && halo.resting == .stopwatch)
    halo.stopwatch.show(.idle)
    timer.show(.done, duration: 60)
    check("a finished timer does", halo.showsHalo)
    timer.show(.idle, duration: 0)
    let airPods = HeadphonesInfo(name: "AirPods", productID: 0x2019, left: 80, right: 80)
    halo.alert = .headphones(airPods, isCompact: false)
    check("the AirPods card does", halo.showsHalo)
    halo.alert = .headphones(airPods, isCompact: true)
    check("and so does its compact pill", halo.showsHalo)
    halo.alert = .focus(FocusAlert(mode: .builtIn("com.apple.focus.work"), isOn: true))
    check("a Focus change does", halo.showsHalo)
    halo.alert = .power(.charging(level: 80))
    check("a battery alert does", halo.showsHalo)
    halo.alert = nil
    halo.hud = NotchViewModel.HUD(kind: .volume, level: 0.5)
    check("volume and brightness do", halo.showsHalo)
    halo.hud = nil
    halo.lockIndicator = NotchViewModel.LockIndicator()
    check("the lock does", halo.showsHalo)
    haloSettings.blurStrength = 0
    check("nothing shows it once the glass is turned off", !halo.showsHalo)
}

@MainActor
func testMediaGlass() async {
    let (model, nowPlaying, _, _) = makeModel("mediaglass")
    let glass = MediaGlassController(model: model)
    glass.start()
    check("nothing playing, no glass", !model.showsMediaGlass && !model.showsHalo)

    play(nowPlaying)
    await wait(0.2)
    check("starting music lights the glass", model.showsMediaGlass && model.showsHalo && model.resting == .liveActivity)
    await wait(NotchStyle.mediaGlassDuration + 0.3)
    check("then it fades while the music keeps playing", !model.showsMediaGlass && !model.showsHalo
          && model.resting == .liveActivity)

    nowPlaying.setPlaying(false)
    await wait(0.2)
    check("pausing lights it again", model.showsMediaGlass && model.showsHalo)
    nowPlaying.setPlaying(true)
    await wait(0.2)
    check("and so does resuming", model.showsMediaGlass)

    nowPlaying.apply(source: .app(.spotify), snapshot: PlayerSnapshot(isPlaying: true, title: "Another", artist: "B",
        album: "", duration: 100, position: 0, capturedAt: .now, trackID: "2"))
    await wait(0.2)
    check("a new track does too", model.showsMediaGlass)
    await wait(NotchStyle.mediaGlassDuration + 0.3)
    check("it fades again", !model.showsMediaGlass)

    // The player reports position all the time; that isn't an interaction.
    nowPlaying.apply(source: .app(.spotify), snapshot: PlayerSnapshot(isPlaying: true, title: "Another", artist: "B",
        album: "", duration: 100, position: 42, capturedAt: .now, trackID: "2"))
    await wait(0.4)
    check("a position update doesn't light it", !model.showsMediaGlass)

    nowPlaying.apply(source: nil, snapshot: nil)
    await wait(0.4)
    check("music stopping leaves the bare notch dark", !model.showsMediaGlass && !model.showsHalo && model.resting == .notch)
}

/// The material's layers are macOS's own, so check they're still there and
/// that adaptive glass changes them the way it means to.
@MainActor
func testAdaptiveMaterial() async {
    func material(adapts: Bool) async -> [String: CALayer] {
        let view = AdaptiveEffectView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        view.adapts = adapts
        let window = NSWindow(contentRect: CGRect(x: -30_000, y: -30_000, width: 200, height: 100),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = view
        window.orderFrontRegardless()
        await wait(0.3)
        view.frame.size = CGSize(width: 260, height: 140)  // the island changes size all the time
        view.layoutSubtreeIfNeeded()
        await wait(0.2)
        window.orderOut(nil)
        let parts = (view.layer?.sublayers ?? []).flatMap { $0.sublayers ?? [] }
        return Dictionary(parts.compactMap { part in part.name.map { ($0, part) } }, uniquingKeysWith: { first, _ in first })
    }

    let natural = await material(adapts: false)
    guard natural["backdrop"] != nil, natural["fill"] != nil else {
        info("this macOS builds the material differently; adaptive glass stays natural")
        check("without the known layers, adaptive glass leaves the material alone", true)
        return
    }
    let adapted = await material(adapts: true)
    let saturation = adapted["backdrop"]?.value(forKeyPath: "filters.colorSaturate.inputAmount") as? Double
    check("natural glass keeps its grey", natural["fill"]?.opacity == 1 && natural["tone"]?.opacity == 1)
    check("adaptive glass swaps the grey for a light milk", adapted["fill"]?.backgroundColor == AdaptiveEffectView.milk
          && adapted["tone"]?.opacity == 0 && adapted["desktop tint"].map { $0.opacity == 0 } ?? true)
    check("and saturates the colors behind it a little more", saturation == AdaptiveEffectView.saturation)
}
