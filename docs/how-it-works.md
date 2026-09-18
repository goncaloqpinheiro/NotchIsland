# How NotchIsland works

Notes for anyone reading or changing the code. The short version: everything is event driven. The app
waits for macOS to announce something (a track change, a key press, a lock, a Focus change) and only
then does any work, so it sits at close to zero CPU while idle.

## Project layout

```
Sources/NotchIsland/
  main.swift     app bootstrap
  App/           delegate, status item, shared menu, logging
  Notch/         panel, geometry, mouse and hover tracking, window controller, view model
  Media/         Spotify, Music and YouTube (browser) monitors, AppleScript runner, now-playing model
  Lock/          lock, unlock and display sleep notifications, lock sequence, lock screen copy of the island
  HUD/           volume and brightness keys, Core Audio volume, display brightness
  Alerts/        AirPods (Bluetooth) and battery (IOKit) alerts, Apple's product animations
  Focus/         Focus files (read with Full Disk Access), FSEvents folder watcher
  Timer/         Clock app timers and stopwatch (read live), Shortcuts based controls, Timer menu
  Sound/         lock, unlock, AirPods and low battery sounds
  Views/         island shape and content, the glass behind it, NotchStyle (sizes, springs, delays)
  Settings/      persisted settings, the Settings window and its tabs
  Debug/         snapshot, README picture and demo renderers, Focus diagnostics
Tests/           checks for the models and controllers (make test)
```

`Views/NotchStyle.swift` holds every size, radius, spring and delay in one place, so the feel can be
tuned by eye.

## The window

- **Geometry**: `NSScreen.auxiliaryTopLeftArea` and `auxiliaryTopRightArea` are the menu bar strips on
  either side of the camera housing. The screen width minus both is the notch width, and
  `safeAreaInsets.top` is its height. Recomputed on `didChangeScreenParametersNotification`.
- **Panel**: a fixed 640 by 300 point transparent `NSPanel` (borderless, non-activating, never key) at
  level `mainMenu + 3`, on all Spaces and over full-screen apps. The island animates inside it, so the
  window never resizes mid-animation.
- **Clicks**: the panel ignores the mouse except while the cursor is over the island, so clicks fall
  through everywhere else. The cursor is tracked with global and local `NSEvent` monitors: no timers,
  so no work while the mouse is still.
- **Hover and click**: resting on the notch for the open delay grows it slightly, with a haptic tick
  and glass behind it. Clicking opens it fully. Leaving closes it.
- **Springs never shrink past the notch**: the island's size animates through a floor at the camera
  housing, so a spring's overshoot can't dip below it and flash the wallpaper around the notch. Measured
  without the floor, the closing spring undershot by 0.8 pt and the morph spring by 8.4 pt.

## The glass

Settings picks what shows behind the island:

- **Frosted Glass** (the default): a behind-window `NSVisualEffectView` blur, masked so it fades out
  toward its edges, with a light rim just inside the island's own outline.
- **Liquid Glass**: `NSGlassEffectView` (macOS 26 and later), kept close to the island as a thin glass
  edge, since it has hard edges. It's only in the macOS 26 SDK, so a build with older Command Line
  Tools (before Swift 6.2) leaves it out and the blur stands in.
- **Blur**: the feathered blur without the rim.

A glass color can stay Natural or be any custom color: a soft glow in the blur's own feathered shape
(Liquid Glass takes it as its tint). Everything follows the Strength slider.

**Adaptive** glass, the default (unless a custom color was picked before it existed), reuses the
material itself. Inside, the material is a live copy of what's behind the
window, kept up to date by the window server, blurred and saturated 2.4 times, under a dark grey fill
at 80% that washes the colors out. Adaptive glass swaps that grey for a 16% white and saturates a bit
more (2.8), so it glows in the colors around the island: the wallpaper, a window, anything. The app
captures and samples nothing, and it costs no more than the natural glass. The layers are macOS's own;
if a future version builds the material differently, the glass stays natural (and `make test` says so).
`make glass-preview` shows Natural and Adaptive side by side over colorful backgrounds.

The README's pictures and demo are drawn by the app, where the window server's glass can't appear. So
they draw adaptive glass themselves: they know the wallpaper behind the island, and blur, saturate and
whiten it the same way with Core Image (`SnapshotBackdrop`), checked against captures of the real glass.

The glass only exists while the island is hovered or open, or showing something that came and went on
its own (an AirPods card, a Focus change, volume, battery, a finished timer, the lock), and for 2.5 s
after a media interaction (music starting, pausing, resuming, or a new track). It stays off for the
rest of a song and while a timer or stopwatch counts down, so the window server isn't blurring all day.
When the island closes, the glass fades in 0.14 s and the rim disappears at once; a slower fade would
drag a visible outline along with the shrinking shape.

## Now Playing

- **Spotify and Music**: since macOS 15.4, MediaRemote only gives now-playing data to Apple signed
  processes (tested on macOS 27: an ordinary process gets nothing back, while sending commands still
  works). Instead, both apps post a distributed notification on every play, pause and track change.
  That drives all updates with no polling and needs no permission. An AppleScript query then fills in
  what the notification lacks (position, artwork, state at launch). Scripts run on a dedicated thread
  and only against apps that are already running, so they never launch a player.
- **YouTube in Chrome or Safari**: browsers don't announce playback, so Core Audio's per process state
  (readable without permission) says when the browser starts or stops making sound. That triggers one
  AppleScript read of its tabs to find the YouTube video. YouTube's public oEmbed endpoint adds the
  title and channel, and the thumbnail becomes the cover. While sound continues, tabs are re-read every
  15 s to catch autoplay. Chrome keeps its audio output running about 10 s after a video pauses, so
  the app also watches media power assertions ("Playing audio"), which Chrome releases about 2 s after
  going quiet; that's the pause signal. Play, pause and next go through MediaRemote commands. There's
  no progress bar for YouTube, because the timeline isn't readable from outside the page.
- **Collapsed**: the art and audio bars beside the notch while playing, and for 8 s after pausing. The
  bars are Core Animation, which runs outside the app process.
- **Open**: the art (click it to switch to the player), title, artist, a seekable progress bar, and
  previous, play or pause, and next.
- **Full screen**: when the notched display shows a full-screen app (its Space type, read from the
  window server on `activeSpaceDidChangeNotification`), the compact music and timer activities hide.

## Timers and stopwatch

The Clock app's own timers, shown the way the Dynamic Island shows them. Clock's timer daemon keeps
them in its preferences (`com.apple.mobiletimerd`, keys `MTTimers` and `MTStopwatches`), and cfprefsd
tells key-value observers about changes made by other processes. So timers started in Clock, with Siri
or from Control Center appear right away, with no polling and no permission.

- The countdown shows beside the camera housing. Open the island for the time shown large, with pause
  and cancel. Music playing at the same time moves to a small bubble beside the island.
- When a timer ends, Clock rings and the island shows it finished until it's stopped.
- The stopwatch shows the same way, in whole seconds.
- Only Clock can change its timers (its daemon requires a private Apple entitlement), so the buttons
  run Clock's own Shortcuts actions through one-action shortcuts you create once. Settings > Clock lists
  them and their status. Without them, the buttons open Clock.
- Nothing ticks in the app: one sleeping task waits for the next change, and the time is redrawn once
  a second, exactly when the shown second changes, and only while visible.

## AirPods

- Connecting is announced by IOBluetooth; battery levels come from private IOBluetooth properties a few
  seconds later. The card shows Apple's own turning 3D animation of that model, the one macOS uses in
  its connection banner (movies with transparency inside BluetoothUIService, named by product ID,
  played from the system, never copied). Models without an animation get a swinging symbol.
- When the AirPods go in your ears, macOS switches the audio output to them, and Core Audio announces
  it. The card then shrinks into a compact pill: the model glides into the left ear and a battery ring
  appears in the right one. Putting them in with no card showing brings up the pill directly. If they
  never become the output, the card shrinks after 6 s anyway.
- Opening the case can't be detected: on macOS 27, bluetoothd doesn't pass the AirPods' Bluetooth LE
  broadcasts to other apps.

## Focus

macOS has no public API or broadcast for the current Focus, so NotchIsland reads the two files it keeps
it in: `~/Library/DoNotDisturb/DB/Assertions.json` (the Focuses turned on) and `ModeConfigurations.json`
(names, symbols and colors). It reads them only when FSEvents reports that one of those two files
changed. The folder is protected, which is why this needs Full Disk Access. `make focus-check` logs
the files' shape (keys only) and what the app reads from them.

## Lock and unlock

- `com.apple.screenIsLocked` and `com.apple.screenIsUnlocked` distributed notifications, plus
  NSWorkspace's display sleep and wake notifications.
- **Center, Then Side** (the default): a closed lock appears below the camera housing and after 2 s
  slides into the ear on its left. On unlock it slides back to the center, the shackle opens (SF
  Symbols Magic Replace), and after a moment it slides left again before the island tucks away.
- **Side Only**: the lock goes straight into the left ear, opens there, and tucks away.
- A lock caused by the display sleeping is shown when the display wakes, not while it's dark.
- While locked, a second copy of the island is placed in a private window-server space above the lock
  screen (SkyLight; the technique comes from Lakr233's SkyLightWindow), so the lock shows there too.
  That window ignores the mouse, never becomes key, and exists only from lock until the unlock
  animation ends.

## Volume and brightness

An event tap intercepts only the volume, mute and brightness keys (they arrive as system-defined
events, not key presses), sets the level itself (Core Audio for the default output, the private
DisplayServices framework for the built-in display), and shows it beside the notch for 1.5 s instead of
the system indicator. Option and Shift together give quarter steps; Option alone still opens Sound or
Displays settings. If a level can't be set (for example, HDMI audio), the key goes to macOS.

## Battery and sounds

- Battery alerts come from IOKit's power source notification: charger plugged in or out, and low
  battery at 20% and 10%.
- Sounds are played from files that ship with macOS (the padlock clicks, a pairing chime, Glass for low
  battery). Charging has none because macOS plays its own chime, and timers have none because Clock
  rings them.

## Permissions

| Permission | Why | Without it |
| --- | --- | --- |
| Automation (Spotify, Music) | Position, artwork and playback controls | Titles and play state still show |
| Automation (Chrome, Safari) | Reads tab titles and URLs to find YouTube videos | YouTube doesn't show |
| Bluetooth | Notices AirPods connecting and reads their battery | No AirPods alerts |
| Accessibility | Intercepts the volume and brightness keys | The system indicator stays |
| Full Disk Access (optional) | Reads the two Focus files | Focus changes don't show |

Timer and stopwatch buttons optionally use shortcuts you create in the Shortcuts app; that needs no
permission, though the first run of each may ask to allow access to Clock.

The ad-hoc signature's designated requirement is pinned to the bundle ID (see `Scripts/bundle.sh`), so
rebuilding keeps these permissions instead of asking again.

## Development

```bash
make run          # build, bundle into build/NotchIsland.app, and (re)launch in the background
make stop         # quit it
make logs         # stream the app's logs
make cpu          # CPU and memory of the running app
make test         # build and run the checks in Tests/ (add ARGS=--verbose to list them)
make snapshots    # render every island state and Settings to build/snapshots
make docs-images  # render the README's pictures into docs/images
make docs-demo    # render the README's animated demo and a 1080p movie of it
make glass-preview  # Natural and Adaptive glass side by side for 20 seconds
make focus-check  # log the Focus files' shape and what the app reads (needs Full Disk Access)
make clean
```

The tests are plain checks compiled together with the app's sources, so they need neither Xcode nor
XCTest. Fakes stand in for Clock, the Shortcuts tool and the screen, and settings go to a temporary
folder, so a run changes nothing on the Mac.

The demo is drawn the way the README's pictures are, by the app itself: an offscreen SwiftUI view steps
through the real animations one frame at a time, and a small built-in encoder writes the GIF.

`make run CONFIG=release` builds an optimized version. `Scripts/bundle.sh` wraps the Swift Package
Manager binary in an `.app` with `Resources/Info.plist` (no Dock icon) and signs it ad-hoc.
