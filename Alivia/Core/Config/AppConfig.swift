import Foundation

/// Backend address. The simulator reaches the computer's localhost; a physical device needs the computer's LAN
/// address. Override it with the `AliviaAPIBaseURL` launch argument or user default
/// (`-AliviaAPIBaseURL http://192.168.1.20:8080/`), or with the `AliviaAPIBaseURL` key of the Info.plist.
enum AppConfig {
    static let defaultBaseURL = "http://localhost:8080/"

    static var apiBaseURL: URL {
        let configured = UserDefaults.standard.string(forKey: "AliviaAPIBaseURL")
            ?? Bundle.main.object(forInfoDictionaryKey: "AliviaAPIBaseURL") as? String
            ?? defaultBaseURL
        let normalized = configured.hasSuffix("/") ? configured : configured + "/"
        return URL(string: normalized) ?? URL(string: defaultBaseURL)!
    }
}
