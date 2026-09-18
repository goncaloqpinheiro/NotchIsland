import Foundation

/// A YouTube video open in a browser tab.
struct YouTubeTab: Equatable, Sendable {
    var videoID: String
    var title: String
    var url: String
}

/// One browser window's tabs, as read by `MediaScripts.browserTabs`.
struct BrowserWindowTabs: Equatable, Sendable {
    var urls: [String]
    var titles: [String]
    /// 1-based index of the window's active tab.
    var activeTab: Int

    /// Parses {{urls}, {titles}, active tab index} per window, front window first.
    static func parse(_ value: ScriptValue) -> [BrowserWindowTabs] {
        guard case .list(let windows) = value else { return [] }
        return windows.compactMap { window in
            guard case .list(let fields) = window, fields.count == 3,
                  case .list(let urls) = fields[0], case .list(let titles) = fields[1],
                  case .number(let activeTab) = fields[2] else { return nil }
            return BrowserWindowTabs(urls: urls.map(\.text), titles: titles.map(\.text), activeTab: Int(activeTab))
        }
    }
}

extension ScriptValue {
    /// The text, or "" for anything else (e.g. `missing value`).
    var text: String {
        if case .text(let string) = self { return string }
        return ""
    }
}

/// Recognizing YouTube videos in browser tabs, and YouTube's public metadata.
enum YouTube {
    /// The video ID in watch, Shorts, live, youtu.be and YouTube Music URLs.
    static func videoID(fromURL string: String) -> String? {
        guard let url = URL(string: string), let host = url.host?.lowercased() else { return nil }
        let path = url.pathComponents  // e.g. ["/", "shorts", "<id>"]
        if host == "youtu.be" {
            return path.count >= 2 ? validID(path[1]) : nil
        }
        guard host == "youtube.com" || host.hasSuffix(".youtube.com") else { return nil }
        if url.path == "/watch" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            return components?.queryItems?.first { $0.name == "v" }?.value.flatMap(validID)
        }
        if path.count >= 3, ["shorts", "live"].contains(path[1]) {
            return validID(path[2])
        }
        return nil
    }

    /// "(3) Some video - YouTube" → "Some video".
    static func cleanTitle(_ title: String) -> String {
        var title = title
        if let unreadCount = title.range(of: #"^\(\d+\+?\)\s+"#, options: .regularExpression) {
            title.removeSubrange(unreadCount)
        }
        for suffix in [" - YouTube Music", " - YouTube"] where title.hasSuffix(suffix) {
            title.removeLast(suffix.count)
            break
        }
        return title
    }

    /// The tab most likely to be playing: the front window's active tab, then
    /// another window's active tab, then any YouTube tab.
    static func likelyPlayingTab(in windows: [BrowserWindowTabs]) -> YouTubeTab? {
        var activeElsewhere: YouTubeTab?
        var background: YouTubeTab?
        for (windowIndex, window) in windows.enumerated() {
            for (index, url) in window.urls.enumerated() {
                guard let videoID = videoID(fromURL: url) else { continue }
                let title = index < window.titles.count ? cleanTitle(window.titles[index]) : ""
                let tab = YouTubeTab(videoID: videoID, title: title, url: url)
                if index + 1 == window.activeTab {
                    if windowIndex == 0 { return tab }
                    activeElsewhere = activeElsewhere ?? tab
                } else {
                    background = background ?? tab
                }
            }
        }
        return activeElsewhere ?? background
    }

    /// The 16:9 thumbnail (the larger ones are letterboxed to 4:3).
    static func thumbnailURL(videoID: String) -> URL? {
        URL(string: "https://i.ytimg.com/vi/\(videoID)/mqdefault.jpg")
    }

    struct VideoInfo: Decodable, Equatable, Sendable {
        let title: String
        let channel: String

        enum CodingKeys: String, CodingKey {
            case title
            case channel = "author_name"
        }
    }

    /// Title and channel from YouTube's public oEmbed endpoint (no API key).
    static func videoInfo(videoID: String) async -> VideoInfo? {
        var components = URLComponents(string: "https://www.youtube.com/oembed")
        components?.queryItems = [
            URLQueryItem(name: "url", value: "https://www.youtube.com/watch?v=\(videoID)"),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let url = components?.url,
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(VideoInfo.self, from: data)
    }

    private static func validID(_ id: String) -> String? {
        let allowed = id.unicodeScalars.allSatisfy { $0.isASCII && CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" }
        return id.count == 11 && allowed ? id : nil
    }
}
