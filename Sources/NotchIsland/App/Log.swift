import OSLog

/// `make logs` streams everything logged under this subsystem.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.goncalopinheiro.NotchIsland"
    static let app = Logger(subsystem: subsystem, category: "app")
    static let notch = Logger(subsystem: subsystem, category: "notch")
    static let media = Logger(subsystem: subsystem, category: "media")
}
