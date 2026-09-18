import AppKit

/// Where the physical notch is, in global screen coordinates (origin bottom-left).
struct NotchGeometry: Equatable {
    let screenFrame: CGRect
    let notchSize: CGSize
    let displayID: CGDirectDisplayID

    /// Returns nil for screens without a camera housing.
    init?(screen: NSScreen) {
        // The auxiliary areas are the menu bar strips left and right of the
        // notch; whatever width they don't cover is the notch itself.
        guard screen.safeAreaInsets.top > 0,
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea else { return nil }
        screenFrame = screen.frame
        notchSize = CGSize(width: screen.frame.width - left.width - right.width,
                           height: screen.safeAreaInsets.top)
        displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    }

    /// The built-in display on a notched MacBook, if it's connected and awake.
    static func current() -> NotchGeometry? {
        NSScreen.screens.lazy.compactMap(NotchGeometry.init(screen:)).first
    }

    /// A rect of `size` hanging from the top edge, centered on the notch.
    func rect(for size: CGSize) -> CGRect {
        CGRect(x: screenFrame.midX - size.width / 2,
               y: screenFrame.maxY - size.height,
               width: size.width,
               height: size.height)
    }
}
