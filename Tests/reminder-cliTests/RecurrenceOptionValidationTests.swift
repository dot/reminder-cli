import ArgumentParser
import XCTest
@testable import reminder_cli

final class RecurrenceOptionValidationTests: XCTestCase {
    private let createBase = ["create", "Task", "--due-date", "2026-12-01"]
    private let updateBase = ["update", "ABCD1234"]

    func testAcceptsRecurrenceWithEitherEndDateOrCount() throws {
        XCTAssertNoThrow(try ReminderCLI.parseAsRoot(createBase + ["--recurrence", "daily", "--recurrence-end", "2026-12-31"]))
        XCTAssertNoThrow(try ReminderCLI.parseAsRoot(createBase + ["--recurrence", "daily", "--recurrence-count", "3"]))
        XCTAssertNoThrow(try ReminderCLI.parseAsRoot(updateBase + ["--recurrence", "daily", "--recurrence-count", "1"]))
        XCTAssertNoThrow(try ReminderCLI.parseAsRoot(updateBase + ["--no-recurrence"]))
    }

    func testRejectsNonPositiveRecurrenceCount() {
        for count in ["0", "-1"] {
            XCTAssertThrowsError(try ReminderCLI.parseAsRoot(createBase + ["--recurrence", "daily", "--recurrence-count", count]), count)
            XCTAssertThrowsError(try ReminderCLI.parseAsRoot(updateBase + ["--recurrence", "daily", "--recurrence-count", count]), count)
        }
    }

    func testRejectsEndDateTogetherWithCount() {
        let options = ["--recurrence", "daily", "--recurrence-end", "2026-12-31", "--recurrence-count", "3"]
        XCTAssertThrowsError(try ReminderCLI.parseAsRoot(createBase + options))
        XCTAssertThrowsError(try ReminderCLI.parseAsRoot(updateBase + options))
    }

    func testRejectsEndConditionWithoutRecurrence() {
        for options in [["--recurrence-end", "2026-12-31"], ["--recurrence-count", "3"]] {
            XCTAssertThrowsError(try ReminderCLI.parseAsRoot(createBase + options), "\(options)")
            XCTAssertThrowsError(try ReminderCLI.parseAsRoot(updateBase + options), "\(options)")
        }
    }

    func testRejectsRecurrenceTogetherWithNoRecurrence() {
        XCTAssertThrowsError(try ReminderCLI.parseAsRoot(updateBase + ["--recurrence", "weekly", "--no-recurrence"]))
    }
}
