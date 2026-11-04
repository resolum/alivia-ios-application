import Foundation

/// MAC addresses as the installation form takes them: 12 hexadecimal digits in pairs separated by colons.
enum MacAddress {
    private static let format = /^([0-9A-F]{2}:){5}[0-9A-F]{2}$/

    /// Upper-cases the text, accepts dashes and inserts the colons while the technician types.
    static func format(_ input: String) -> String {
        let digits = Array(input.uppercased().filter { ("0"..."9").contains($0) || ("A"..."F").contains($0) }.prefix(12))
        return stride(from: 0, to: digits.count, by: 2)
            .map { String(digits[$0..<min($0 + 2, digits.count)]) }
            .joined(separator: ":")
    }

    static func isValid(_ value: String) -> Bool { (try? format.wholeMatch(in: value)) != nil }
}
