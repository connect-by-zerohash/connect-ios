import Foundation

/// UUID identifying the SDK-private `WKWebsiteDataStore`. Stored once in
/// `UserDefaults.standard` so cookies set during a Coinbase login survive
/// app restart (smoke checkpoint 3 step 10) but never leak into the host
/// app's other WebViews (PR #22 review item R5).
enum SDKDataStoreIdentifier {
    static let userDefaultsKey = "xyz.connect.sdk.dataStoreId"

    /// Process-wide cached value. First access triggers a `UserDefaults`
    /// read (and a write if no value exists yet).
    static let shared: UUID = read(from: .standard)

    /// Read-or-create. Exposed for tests that want to use a custom suite.
    static func read(from defaults: UserDefaults) -> UUID {
        if let raw = defaults.string(forKey: userDefaultsKey),
           let uuid = UUID(uuidString: raw) {
            return uuid
        }
        let uuid = UUID()
        defaults.set(uuid.uuidString, forKey: userDefaultsKey)
        return uuid
    }
}
