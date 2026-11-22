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
