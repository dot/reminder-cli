@preconcurrency import EventKit
import Foundation

enum RecurrenceParser {
    /// Parse a recurrence string into an EKRecurrenceRule.
    ///
    /// Supported formats:
    /// - `"daily"`, `"weekly"`, `"monthly"`, `"yearly"`
    /// - `"every 2 days"`, `"every 3 weeks"`, etc.
    /// - `"weekly:mon,wed,fri"` (days of week for weekly)
    /// - `"every 2 weeks:mon,fri"` (interval + days)
    static func parse(from string: String, end: EKRecurrenceEnd? = nil) throws -> EKRecurrenceRule {
        let input = string.lowercased().trimmingCharacters(in: .whitespaces)

        // Split on ":" to separate frequency from days
        let parts = input.split(separator: ":", maxSplits: 1)
        let frequencyPart = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let daysPart = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : nil

        let (frequency, interval) = try parseFrequency(frequencyPart)
        let daysOfWeek = try daysPart.map { try parseDaysOfWeek($0) }

        if daysOfWeek != nil && frequency != .weekly {
            throw ReminderStoreError.invalidRecurrence(
                "Days of the week can only be specified with weekly recurrence"
            )
        }

        return EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            daysOfTheWeek: daysOfWeek,
            daysOfTheMonth: nil,
            monthsOfTheYear: nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: end
        )
    }

    private static func parseFrequency(_ string: String) throws -> (EKRecurrenceFrequency, Int) {
        // Simple: "daily", "weekly", "monthly", "yearly"
        if let freq = frequencyFromString(string) {
            return (freq, 1)
        }

        // Interval: "every N days/weeks/months/years"
        let words = string.split(separator: " ")
        if words.count == 3,
           words[0] == "every",
           let interval = Int(words[1]),
           interval > 0 {
            let unit = String(words[2])
            // Accept both singular and plural
            if let freq = frequencyFromUnit(unit) {
                return (freq, interval)
            }
        }

        throw ReminderStoreError.invalidRecurrence(string)
    }

    private static func frequencyFromString(_ string: String) -> EKRecurrenceFrequency? {
        switch string {
        case "daily": return .daily
        case "weekly": return .weekly
        case "monthly": return .monthly
        case "yearly": return .yearly
        default: return nil
        }
    }

    private static func frequencyFromUnit(_ unit: String) -> EKRecurrenceFrequency? {
        switch unit {
        case "day", "days": return .daily
        case "week", "weeks": return .weekly
        case "month", "months": return .monthly
        case "year", "years": return .yearly
        default: return nil
        }
    }

    private static func parseDaysOfWeek(_ string: String) throws -> [EKRecurrenceDayOfWeek] {
        let dayStrings = string.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }

        let days = try dayStrings.map { dayString -> EKRecurrenceDayOfWeek in
            guard let day = dayOfWeekFromString(dayString) else {
                throw ReminderStoreError.invalidRecurrence(
                    "Unknown day: \(dayString). Use: sun,mon,tue,wed,thu,fri,sat"
                )
            }
            return day
        }

        if days.isEmpty {
            throw ReminderStoreError.invalidRecurrence("No days specified")
        }

        return days
    }

    private static func dayOfWeekFromString(_ string: String) -> EKRecurrenceDayOfWeek? {
        switch string {
        case "sun", "sunday": return EKRecurrenceDayOfWeek(.sunday)
        case "mon", "monday": return EKRecurrenceDayOfWeek(.monday)
        case "tue", "tuesday": return EKRecurrenceDayOfWeek(.tuesday)
        case "wed", "wednesday": return EKRecurrenceDayOfWeek(.wednesday)
        case "thu", "thursday": return EKRecurrenceDayOfWeek(.thursday)
        case "fri", "friday": return EKRecurrenceDayOfWeek(.friday)
        case "sat", "saturday": return EKRecurrenceDayOfWeek(.saturday)
        default: return nil
        }
    }
}
