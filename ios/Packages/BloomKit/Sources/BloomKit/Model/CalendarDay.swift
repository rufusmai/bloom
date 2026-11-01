import Foundation

/// A calendar day without a time or a time zone, e.g. `2026-11-01`.
///
/// Cycle data is about *days*, not instants. Storing a `Date` would shift
/// entries when the user travels across time zones or when daylight saving time
/// changes. `CalendarDay` uses pure proleptic Gregorian arithmetic, so it behaves
/// the same on every platform.
public struct CalendarDay: Hashable, Sendable, Identifiable {
    public let year: Int
    public let month: Int
    public let day: Int

    public var id: Int { ordinal }

    /// Creates a day. Out-of-range values roll over,
    /// e.g. `2026-02-30` becomes `2026-03-02` and month `13` becomes January of the next year.
    public init(year: Int, month: Int, day: Int) {
        var (yearOffset, monthIndex) = (month - 1).quotientAndRemainder(dividingBy: 12)
        if monthIndex < 0 {
            monthIndex += 12
            yearOffset -= 1
        }
        let firstOfMonth = Self.daysFromCivil(year: year + yearOffset, month: monthIndex + 1, day: 1)
        self.init(ordinal: firstOfMonth + day - 1)
    }

    /// Creates a day from the number of days since 1970-01-01.
    public init(ordinal: Int) {
        let (year, month, day) = Self.civilFromDays(ordinal)
        self.year = year
        self.month = month
        self.day = day
    }

    /// Number of days since 1970-01-01 (negative before).
    public var ordinal: Int {
        Self.daysFromCivil(year: year, month: month, day: day)
    }
}

// MARK: - Arithmetic

extension CalendarDay {
    public func adding(days: Int) -> CalendarDay {
        CalendarDay(ordinal: ordinal + days)
    }

    /// Whole days from `other` to `self`. Positive if `self` is later.
    public func days(since other: CalendarDay) -> Int {
        ordinal - other.ordinal
    }

    /// Weekday in Foundation numbering: 1 = Sunday … 7 = Saturday.
    public var weekday: Int {
        // 1970-01-01 was a Thursday (5).
        let mod = ((ordinal % 7) + 7) % 7
        return (mod + 4) % 7 + 1
    }

    public var firstOfMonth: CalendarDay {
        CalendarDay(year: year, month: month, day: 1)
    }

    public var numberOfDaysInMonth: Int {
        CalendarDay(year: year, month: month + 1, day: 1).days(since: firstOfMonth)
    }

    /// Adds months, clamping the day to the target month (Jan 31 + 1 month = Feb 28/29).
    public func adding(months: Int) -> CalendarDay {
        let target = CalendarDay(year: year, month: month + months, day: 1)
        return CalendarDay(year: target.year, month: target.month, day: min(day, target.numberOfDaysInMonth))
    }
}

extension CalendarDay: Comparable {
    public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

extension CalendarDay: Strideable {
    public func distance(to other: CalendarDay) -> Int {
        other.ordinal - ordinal
    }

    public func advanced(by n: Int) -> CalendarDay {
        adding(days: n)
    }
}

// MARK: - ISO 8601 (yyyy-MM-dd)

extension CalendarDay: CustomStringConvertible, LosslessStringConvertible {
    /// Parses `yyyy-MM-dd`. Returns `nil` for malformed or out-of-range values.
    public init?(_ isoString: String) {
        let parts = isoString.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), day >= 1
        else { return nil }
        let candidate = CalendarDay(year: year, month: month, day: day)
        guard candidate.month == month, candidate.day == day else { return nil }
        self = candidate
    }

    public var isoString: String {
        func pad(_ value: Int, _ width: Int) -> String {
            let digits = String(value)
            return String(repeating: "0", count: max(0, width - digits.count)) + digits
        }
        return "\(pad(year, 4))-\(pad(month, 2))-\(pad(day, 2))"
    }

    public var description: String { isoString }
}

extension CalendarDay: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let value = CalendarDay(string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid calendar day: \(string)")
        }
        self = value
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(isoString)
    }
}

// MARK: - Foundation bridging

extension CalendarDay {
    private static func gregorian(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// The local calendar day of `date` in `timeZone`.
    public init(_ date: Date, timeZone: TimeZone = .current) {
        let components = Self.gregorian(in: timeZone).dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year ?? 1970, month: components.month ?? 1, day: components.day ?? 1)
    }

    /// The start of this day in `timeZone`.
    public func date(in timeZone: TimeZone = .current) -> Date {
        let components = DateComponents(year: year, month: month, day: day)
        return Self.gregorian(in: timeZone).date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    public static func today(in timeZone: TimeZone = .current) -> CalendarDay {
        CalendarDay(Date(), timeZone: timeZone)
    }
}

// MARK: - Civil date algorithms (Howard Hinnant, public domain)

extension CalendarDay {
    static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400
        let shiftedMonth = month > 2 ? month - 3 : month + 9
        let dayOfYear = (153 * shiftedMonth + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    static func civilFromDays(_ days: Int) -> (year: Int, month: Int, day: Int) {
        let z = days + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let dayOfEra = z - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let shiftedMonth = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * shiftedMonth + 2) / 5 + 1
        let month = shiftedMonth < 10 ? shiftedMonth + 3 : shiftedMonth - 9
        let year = yearOfEra + era * 400 + (month <= 2 ? 1 : 0)
        return (year, month, day)
    }
}
