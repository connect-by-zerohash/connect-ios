//
//  Log.swift
//  ConnectSDK
//
//  Lightweight logging shim. All output goes through os_log under DEBUG
//  builds only — release builds (e.g. App Store submissions) compile the
//  calls down to no-ops so the SDK does not leak diagnostic strings to
//  the unified logging system at runtime.
//

import Foundation
import os
import os.log

internal enum Log {

    private static let subsystem = "com.zerohash.connect.sdk"
    private static let osLog = OSLog(subsystem: subsystem, category: "ConnectSDK")

    static func error(_ message: @autoclosure () -> String) {
        #if DEBUG
        os_log("%{public}@", log: osLog, type: .error, message())
        #endif
    }

    static func debug(_ message: @autoclosure () -> String) {
        #if DEBUG
        os_log("%{public}@", log: osLog, type: .debug, message())
        #endif
    }
}

// MARK: - Bridge/Automation structured loggers
//
// The ZeroAuth bridge, automation, and platform layers use per-area
// `os.Logger` instances (privacy-tagged interpolation) plus an `OSLog`
// for `os_signpost` interval markers in Instruments. These live alongside
// the lightweight `Log.error`/`Log.debug` shim above.
extension Log {
    private static let bridgeSubsystem = "xyz.connect.sdk"

    static let bridge   = Logger(subsystem: bridgeSubsystem, category: "bridge")
    static let automation = Logger(subsystem: bridgeSubsystem, category: "automation")
    static let runner   = Logger(subsystem: bridgeSubsystem, category: "runner")
    static let coinbase = Logger(subsystem: bridgeSubsystem, category: "coinbase")

    /// `OSLog` instance dedicated to signposts. Use with `os_signpost`
    /// `.begin` / `.end` around runner stages.
    static let signposts = OSLog(subsystem: bridgeSubsystem, category: .pointsOfInterest)
}
