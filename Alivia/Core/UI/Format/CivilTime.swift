import Foundation

/// Calendar day without a time zone, like `java.time.LocalDate`. Days are counted in Lima, where the homes are.
struct LocalDate: Hashable, Comparable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    static let zone = TimeZone(identifier: "America/Lima")!

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    /// Parses "2026-11-03".
    init?(iso value: String?) {
        guard let value else { return nil }
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(_ date: Date) {
        let parts = LocalDate.calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    static func today(now: Date = Date()) -> LocalDate { LocalDate(now) }

    /// Noon of the day in Lima, safe for formatting and arithmetic.
    var date: Date {
        LocalDate.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date()
    }

    func plusDays(_ days: Int) -> LocalDate {
        LocalDate(LocalDate.calendar.date(byAdding: .day, value: days, to: date) ?? date)
    }

    func plusWeeks(_ weeks: Int) -> LocalDate { plusDays(weeks * 7) }

    /// Monday of the week of this day.
    var monday: LocalDate {
        let weekday = LocalDate.calendar.component(.weekday, from: date) // 1 = Sunday
        return plusDays(-((weekday + 5) % 7))
    }

    /// ISO week number.
    var isoWeek: Int {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = LocalDate.zone
        return calendar.component(.weekOfYear, from: date)
    }

    static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

/// Time of day without a date, like `java.time.LocalTime`.
struct LocalTime: Hashable, Comparable, Sendable {
    let hour: Int
    let minute: Int

    /// Parses "09:00" or "09:00:00".
    init?(iso value: String?) {
        guard let value else { return nil }
        let parts = value.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2, (0...23).contains(parts[0]), (0...59).contains(parts[1]) else { return nil }
        self.init(hour: parts[0], minute: parts[1])
    }

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    static func < (lhs: LocalTime, rhs: LocalTime) -> Bool {
        (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
    }
}

enum InstantParser {
    /// Parses ISO-8601 instants with or without fractional seconds ("2026-11-03T15:07:30.123Z").
    static func parse(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: value) { return date }
        return ISO8601DateFormatter().date(from: value)
    }
}
