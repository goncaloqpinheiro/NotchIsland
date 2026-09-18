import SwiftUI

/// Root of the panel: the island hanging from the top-center of the canvas.
struct NotchRootView: View {
    let model: NotchViewModel
    let actions: NowPlayingActions
    var timerActions = TimerActions()
    var stopwatchActions = StopwatchActions()

    var body: some View {
        ZStack(alignment: .top) {
            if model.showsHalo {
                let spread = model.glass.spread
                IslandBackdrop(glass: model.glass, strength: model.blurStrength,
                               cornerRadius: model.bottomCornerRadius + spread, tint: model.glassTint,
                               adapts: model.glassAdapts)
                    .frame(width: model.shapeSize.width + 2 * spread,
                           height: model.shapeSize.height + 2 * spread)
                    // Push the top above the screen edge, so it reaches all the way up to it.
                    .offset(y: -spread)
                    .transition(.asymmetric(insertion: .opacity, removal: .opacity.animation(NotchStyle.glassOut)))
            }
            if model.showsMusicBubble {
                let diameter = model.notchSize.height
                // Behind the island, so it slides out from under its edge.
                MusicBubbleView(nowPlaying: model.nowPlaying, diameter: diameter)
                    .offset(x: model.shapeSize.width / 2 + NotchStyle.bubbleGap + diameter / 2)
                    .transition(.bubbleSplit(distance: NotchStyle.bubbleGap + diameter))
            }
            island
        }
        // Music or a timer starting or stopping resizes the island without a hover or click.
        .animation(NotchStyle.expand, value: model.showsLiveActivity)
        .animation(NotchStyle.expand, value: model.showsMusicBubble)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // The island is always black, so its content always uses dark appearance.
        .environment(\.colorScheme, .dark)
        // Windows overlapping the notch can get a top safe-area inset;
        // ignore it so the shape stays flush with the screen edge.
        .ignoresSafeArea()
    }

    private var island: some View {
        let shape = NotchShape(topCornerRadius: model.topCornerRadius,
                               bottomCornerRadius: model.bottomCornerRadius)
        return shape
            .fill(.black)
            .islandSize(model.shapeSize, atLeast: model.notchSize)
            .overlay(alignment: .top) { content }
            .clipShape(shape)
            .overlay {
                // A light edge along the outline, the way glass catches light.
                if model.showsHalo && model.glass.showsRim {
                    shape
                        .stroke(LinearGradient(colors: [.white.opacity(NotchStyle.rimOpacity.top),
                                                        .white.opacity(NotchStyle.rimOpacity.bottom)],
                                               startPoint: .top, endPoint: .bottom),
                                lineWidth: NotchStyle.rimWidth)
                        .clipShape(shape)  // keep it inside the island's own edge
                        // Gone at once when the island starts closing: a fading
                        // outline would trace the shape all the way down.
                        .transition(.asymmetric(insertion: .opacity, removal: .identity))
                }
                if model.isCalibrating && model.shapeSize == model.notchSize {
                    shape.stroke(.red, lineWidth: 1)
                }
            }
    }

    /// Laid out at its final size and revealed by the clip as the island grows,
    /// so nothing reflows mid-animation.
    @ViewBuilder
    private var content: some View {
        let notch = model.notchSize
        if model.isExpanded {
            ExpandedIslandView(model: model, actions: actions, timerActions: timerActions, stopwatchActions: stopwatchActions)
                .transition(.islandContent)
        } else {
            switch model.resting {
            case .lock:
                if let indicator = model.lockIndicator {
                    LockIndicatorView(indicator: indicator, size: model.lockSize, notchSize: notch)
                        .transition(.islandContent)
                }
            case .hud:
                if let hud = model.hud {
                    HUDView(hud: hud, size: model.hudSize, notchWidth: notch.width)
                        .transition(.islandContent)
                }
            case .headphones:
                if case .headphones(let info, let isCompact)? = model.alert {
                    HeadphonesAlertView(info: info, isCompact: isCompact, size: model.restingSize, notchSize: notch)
                        .transition(.islandContent)
                }
            case .power:
                if case .power(let alert)? = model.alert {
                    PowerAlertView(alert: alert, size: model.powerAlertSize, notchWidth: notch.width)
                        .transition(.islandContent)
                }
            case .focus:
                if case .focus(let alert)? = model.alert {
                    FocusAlertView(alert: alert, size: model.focusAlertSize, notchWidth: notch.width)
                        .transition(.islandContent)
                }
            case .timerDone:
                TimerSectionView(timer: model.timer, actions: timerActions)
                    .padding(.top, notch.height)
                    .frame(width: model.timerAlertSize.width, height: model.timerAlertSize.height, alignment: .top)
                    .transition(.islandContent)
            case .timer:
                TimerActivityView(timer: model.timer, size: model.timerActivitySize, notchWidth: notch.width)
                    .transition(.islandContent)
            case .stopwatch:
                StopwatchActivityView(stopwatch: model.stopwatch, size: model.timerActivitySize, notchWidth: notch.width)
                    .transition(.islandContent)
            case .liveActivity:
                LiveActivityView(nowPlaying: model.nowPlaying, size: model.liveActivitySize, notchWidth: notch.width)
                    .transition(.islandContent)
            case .notch:
                EmptyView()
            }
        }
    }
}
