//
//  ConnectAllowList.swift
//  ConnectSDK
//
//  Public allow-list of hosts that the SDK is permitted to navigate
//  to or load resources from. Integrators can supply their own list
//  (e.g. fetched over the air) instead of using the SDK default.
//

import Foundation

public struct ConnectAllowList: Sendable, Equatable {

    /// Hosts whose resources and navigations are permitted. A host
    /// matches if it is exactly equal to an entry, or if it ends with
    /// `"." + entry` (so `"connect.xyz"` covers `"sdk.connect.xyz"` but
    /// not `"evilconnect.xyz"` or `"connect.xyz.attacker.com"`).
    public let hosts: [String]

    public init(hosts: [String]) {
        self.hosts = hosts
    }

    /// The default allow-list shipped with the SDK.
    public static let `default` = ConnectAllowList(hosts: ["connect.xyz", "zerohash.com"])

    /// Returns `true` if `host` is permitted under this allow-list.
    public func contains(host: String) -> Bool {
        let lowered = host.lowercased()
        return hosts.contains { entry in
            let target = entry.lowercased()
            return lowered == target || lowered.hasSuffix("." + target)
        }
    }
}
