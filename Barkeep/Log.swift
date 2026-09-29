import OSLog

/// View with: log stream --level info --predicate 'subsystem == "com.samuelphifer.Barkeep"'
enum Log {
    static let menuBar = Logger(subsystem: "com.samuelphifer.Barkeep", category: "menubar")
}
