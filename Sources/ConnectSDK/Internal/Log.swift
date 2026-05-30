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
