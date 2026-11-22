@preconcurrency import EventKit
import XCTest
@testable import reminder_cli

final class RecurrenceParserTests: XCTestCase {
    func testParsesSimpleFrequencies() throws {
        let expected: [String: EKRecurrenceFrequency] = [
            "daily": .daily, "weekly": .weekly, "monthly": .monthly, "yearly": .yearly,
        ]
        for (input, frequency) in expected {
            let rule = try RecurrenceParser.parse(from: input)
            XCTAssertEqual(rule.frequency, frequency, input)
            XCTAssertEqual(rule.interval, 1, input)
        }
    }

    func testParsesIntervalWithSingularOrPluralUnit() throws {
        let rule = try RecurrenceParser.parse(from: "every 2 weeks")
        XCTAssertEqual(rule.frequency, .weekly)
        XCTAssertEqual(rule.interval, 2)
        XCTAssertEqual(try RecurrenceParser.parse(from: "every 1 day").frequency, .daily)
    }

    func testParsesWeeklyDaysCaseInsensitively() throws {
        let rule = try RecurrenceParser.parse(from: "Weekly:MON,wed, Fri")
        XCTAssertEqual(rule.daysOfTheWeek?.map(\.dayOfTheWeek), [.monday, .wednesday, .friday])
    }

    func testParsesIntervalWithDays() throws {
        let rule = try RecurrenceParser.parse(from: "every 2 weeks:mon,fri")
        XCTAssertEqual(rule.interval, 2)
        XCTAssertEqual(rule.daysOfTheWeek?.map(\.dayOfTheWeek), [.monday, .friday])
    }

    func testRejectsEmptyOrBlankInput() {
        for input in ["", "   "] {
            XCTAssertThrowsError(try RecurrenceParser.parse(from: input), "'\(input)'")
        }
    }

    func testRejectsWeeklyWithEmptyDayList() {
        XCTAssertThrowsError(try RecurrenceParser.parse(from: "weekly:"))
        XCTAssertThrowsError(try RecurrenceParser.parse(from: "weekly:mon,,fri"))
    }

    func testRejectsDaysForNonWeeklyFrequency() {
        XCTAssertThrowsError(try RecurrenceParser.parse(from: "daily:mon"))
    }

    func testRejectsUnknownDayFrequencyAndNonPositiveInterval() {
        XCTAssertThrowsError(try RecurrenceParser.parse(from: "weekly:funday"))
        XCTAssertThrowsError(try RecurrenceParser.parse(from: "hourly"))
        XCTAssertThrowsError(try RecurrenceParser.parse(from: "every 0 days"))
    }
}

final class RecurrenceEndDateTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    func testDateOnlyEndIncludesTheWholeLastDay() throws {
        let end = try XCTUnwrap(RecurrenceParser.endDate(
            from: DateComponents(year: 2026, month: 12, day: 10), calendar: calendar
        ))
        let lastOccurrence = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 12, day: 10, hour: 23, minute: 59)))
        let nextDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 12, day: 11)))
        XCTAssertGreaterThanOrEqual(end, lastOccurrence)
        XCTAssertLessThan(end, nextDay)
    }

    func testTimedEndIsUsedAsGiven() throws {
        let components = DateComponents(year: 2026, month: 12, day: 10, hour: 18, minute: 0)
        XCTAssertEqual(RecurrenceParser.endDate(from: components, calendar: calendar), calendar.date(from: components))
    }
}
