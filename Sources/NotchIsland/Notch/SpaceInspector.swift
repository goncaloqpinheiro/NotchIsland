import AppKit

/// Asks the window server what a display is currently showing.
enum SpaceInspector {
    /// True when the display's current Space belongs to a full-screen app
    /// (Split View included).
    static func isFullScreen(displayID: CGDirectDisplayID) -> Bool {
        if let type = currentSpaceType(displayID: displayID) {
            return type == fullScreenSpaceType
        }
        return windowCoversDisplay(displayID)
    }

    // MARK: SkyLight (private, the same calls tiling window managers use)

    private static let fullScreenSpaceType: Int32 = 4
    private static let currentSpace = SkyLight.function("SLSManagedDisplayGetCurrentSpace", as: (@convention(c) (Int32, CFString) -> UInt64).self)
    private static let spaceType = SkyLight.function("SLSSpaceGetType", as: (@convention(c) (Int32, UInt64) -> Int32).self)

    private static func currentSpaceType(displayID: CGDirectDisplayID) -> Int32? {
        guard let mainConnectionID = SkyLight.mainConnectionID, let currentSpace, let spaceType,
              let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue(),
              let uuidString = CFUUIDCreateString(nil, uuid) else { return nil }
        let connection = mainConnectionID()
        return spaceType(connection, currentSpace(connection, uuidString))
    }

    // MARK: Fallback (public API), in case a macOS update removes the calls above

    /// A regular window as large as the whole display, menu bar area included.
    private static func windowCoversDisplay(_ displayID: CGDirectDisplayID) -> Bool {
        let displayBounds = CGDisplayBounds(displayID)  // same top-left origin as window bounds
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.contains { window in
            guard window[kCGWindowLayer as String] as? Int == 0,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return false }
            return frame == displayBounds
        }
    }
}
