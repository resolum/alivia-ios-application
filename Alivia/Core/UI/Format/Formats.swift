import Foundation

/// Dates and times in Peruvian Spanish, as the designs show them ("Hoy, 24 de octubre · 9:00 a. m.").
enum Formats {
    static let locale = Locale(identifier: "es_PE")

    private static func formatter(_ pattern: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = LocalDate.zone
        formatter.calendar = LocalDate.calendar
        formatter.dateFormat = pattern
        return formatter
    }

    private static let dayMonth = formatter("d 'de' MMMM")
    private static let weekdayDayMonth = formatter("EEEE d 'de' MMMM")
    private static let timeFormat = formatter("h:mm a")
    private static let monthYearFormat = formatter("MMMM yyyy")
    private static let shortDay = formatter("d MMM")
    private static let shortWeekday = formatter("EEE")

    static func today() -> LocalDate { LocalDate.today() }

    static func time(_ value: LocalTime) -> String {
        let date = LocalDate.calendar.date(bySettingHour: value.hour, minute: value.minute, second: 0, of: LocalDate.today().date)
        return timeFormat.string(from: date ?? Date())
    }

    static func time(_ value: Date) -> String { timeFormat.string(from: value) }

    static func window(_ start: LocalTime, _ end: LocalTime) -> String { "\(time(start)) – \(time(end))" }

    /// "Hoy, 24 de octubre", "Mañana, 25 de octubre" or "Lunes 28 de octubre".
    static func day(_ date: LocalDate, today: LocalDate = today()) -> String {
        switch date {
        case today: return "Hoy, \(dayMonth.string(from: date.date))"
        case today.plusDays(1): return "Mañana, \(dayMonth.string(from: date.date))"
        case today.plusDays(-1): return "Ayer, \(dayMonth.string(from: date.date))"
        default: return capitalizedFirst(weekdayDayMonth.string(from: date.date))
        }
    }

    static func monthYear(_ date: LocalDate) -> String { capitalizedFirst(monthYearFormat.string(from: date.date)) }

    /// "LUN", "MAR"… for the week strip.
    static func shortWeekdayName(_ date: LocalDate) -> String {
        shortWeekday.string(from: date.date).uppercased(with: locale).trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    /// "10:14 a. m. · Hoy, 24 oct" for the moment an order closed.
    static func moment(_ value: Date, today: LocalDate = today()) -> String {
        let date = LocalDate(value)
        let short = shortDay.string(from: value)
        let dayText: String
        switch date {
        case today: dayText = "Hoy, \(short)"
        case today.plusDays(-1): dayText = "Ayer, \(short)"
        default: dayText = short
        }
        return "\(time(value)) · \(dayText)"
    }

    private static func capitalizedFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).uppercased(with: locale) + text.dropFirst()
    }
}
