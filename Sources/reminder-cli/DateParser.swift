import Foundation

enum DateParser {
    static func parseDateComponents(from string: String) throws -> DateComponents {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Try with time first
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        if let date = formatter.date(from: string) {
            return Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        }

        // Try date only
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: string) {
            return Calendar.current.dateComponents([.year, .month, .day], from: date)
        }

        throw ReminderStoreError.invalidDateFormat(string)
    }
}
