import Foundation

/// Play/pause, next and previous for whatever macOS considers the active media
/// session, e.g. a YouTube tab. Since macOS 15.4 MediaRemote no longer tells
/// ordinary apps what's playing, but it still accepts these commands.
enum MediaRemoteCommands {
    private typealias SendCommand = @convention(c) (Int32, CFDictionary?) -> Bool

    private static let sendCommand: SendCommand? = {
        guard let framework = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY),
              let function = dlsym(framework, "MRMediaRemoteSendCommand") else { return nil }
        return unsafeBitCast(function, to: SendCommand.self)
    }()

    static func send(_ command: MediaCommand) {
        let code: Int32
        switch command {
        case .togglePlayPause: code = 2
        case .next: code = 4
        case .previous: code = 5
        case .seek: return  // not available this way
        }
        _ = sendCommand?(code, nil)
    }
}
