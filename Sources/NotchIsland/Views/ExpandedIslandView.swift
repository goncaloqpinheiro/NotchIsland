import SwiftUI

/// The open island: Now Playing, with the Clock timer (or else the stopwatch)
/// above it while one is going.
struct ExpandedIslandView: View {
    let model: NotchViewModel
    let actions: NowPlayingActions
    let timerActions: TimerActions
    let stopwatchActions: StopwatchActions

    var body: some View {
        let size = model.expandedSize
        let nowPlaying = model.nowPlaying
        let notchHeight = model.notchSize.height
        let showsClock = model.showsTimerSection || model.showsStopwatchSection
        let clockHeight = showsClock ? NotchStyle.timerSectionHeight : 0
        ZStack(alignment: .top) {
            if model.showsTimerSection {
                TimerSectionView(timer: model.timer, actions: timerActions)
                    .frame(width: size.width)
                    .padding(.top, notchHeight)
                    .transition(.opacity)
            } else if model.showsStopwatchSection {
                StopwatchSectionView(stopwatch: model.stopwatch, actions: stopwatchActions)
                    .frame(width: size.width)
                    .padding(.top, notchHeight)
                    .transition(.opacity)
            }
            if showsClock {
                if nowPlaying.hasTrack {
                    Rectangle()
                        .fill(.white.opacity(0.12))
                        .frame(height: 0.5)
                        .padding(.horizontal, 22)
                        .padding(.top, notchHeight + clockHeight)
                }
            }
            if nowPlaying.hasTrack {
                NowPlayingView(nowPlaying: nowPlaying, size: size, notchHeight: notchHeight + clockHeight,
                               actions: actions)
            } else if !showsClock {
                NotPlayingView(size: size, notchHeight: notchHeight,
                               deniedSource: nowPlaying.deniedSources.first,
                               onOpenAutomationSettings: actions.openAutomationSettings)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
    }
}
