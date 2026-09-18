import AppKit

/// A private window-server space composited above the lock screen: the
/// technique from Lakr233/SkyLightWindow, which Atoll uses for its lock screen
/// widgets. Absolute space levels: 200 password dialogs, 300 lock screen,
/// 400 notifications shown over the lock screen.
@MainActor
final class LockScreenSpace {
    private typealias CreateSpace = @convention(c) (Int32, Int, CFDictionary?) -> UInt64
    private typealias SetAbsoluteLevel = @convention(c) (Int32, UInt64, Int32) -> Void
    private typealias ShowSpaces = @convention(c) (Int32, CFArray) -> Void
    private typealias MoveWindows = @convention(c) (Int32, UInt64, CFArray, Int32) -> Void

    private static let createSpace = SkyLight.function("SLSSpaceCreate", as: CreateSpace.self)
    private static let setAbsoluteLevel = SkyLight.function("SLSSpaceSetAbsoluteLevel", as: SetAbsoluteLevel.self)
    private static let showSpaces = SkyLight.function("SLSShowSpaces", as: ShowSpaces.self)
    private static let moveWindows = SkyLight.function("SLSSpaceAddWindowsAndRemoveFromSpaces", as: MoveWindows.self)
    private static let aboveLockScreen: Int32 = 400

    static var isAvailable: Bool {
        SkyLight.mainConnectionID != nil && createSpace != nil && setAbsoluteLevel != nil
            && showSpaces != nil && moveWindows != nil
    }

    /// Created on first use and kept for the app's lifetime; the window server
    /// removes it when the app quits.
    private var space: UInt64?

    /// Moves an on-screen window into the space. Returns false if unavailable.
    func add(_ window: NSWindow) -> Bool {
        guard let connection = SkyLight.mainConnectionID?(),
              let moveWindows = Self.moveWindows,
              let space = space ?? makeSpace(connection: connection) else { return false }
        // 7: also remove the window from every other space it's in.
        moveWindows(connection, space, [NSNumber(value: window.windowNumber)] as CFArray, 7)
        return true
    }

    private func makeSpace(connection: Int32) -> UInt64? {
        guard let createSpace = Self.createSpace, let setAbsoluteLevel = Self.setAbsoluteLevel,
              let showSpaces = Self.showSpaces else { return nil }
        let created = createSpace(connection, 1, nil)
        guard created != 0 else { return nil }
        setAbsoluteLevel(connection, created, Self.aboveLockScreen)
        showSpaces(connection, [NSNumber(value: created)] as CFArray)
        space = created
        return created
    }
}
