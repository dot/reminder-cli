@preconcurrency import EventKit
import XCTest
@testable import reminder_cli

final class DueDateAlarmTests: XCTestCase {
    func testTimedDueDateNeedsAlarm() {
        let timed = DateComponents(year: 2026, month: 12, day: 3, hour: 9, minute: 0)
        XCTAssertTrue(DueDateAlarm.needsAlarm(for: timed))
    }

    func testDateOnlyDueDateDoesNotNeedAlarm() {
        let dateOnly = DateComponents(year: 2026, month: 12, day: 3)
        XCTAssertFalse(DueDateAlarm.needsAlarm(for: dateOnly))
    }

    func testDueDateChangeDropsAtDueTimeAlarm() {
        let atDueTime = EKAlarm(relativeOffset: 0)
        XCTAssertEqual(DueDateAlarm.alarmsToRemove(from: [atDueTime]), [atDueTime])
    }

    func testDueDateChangeKeepsUserDefinedAlarms() {
        let tenMinutesBefore = EKAlarm(relativeOffset: -600)
        let absolute = EKAlarm(absoluteDate: Date(timeIntervalSince1970: 1_800_000_000))
        let location = EKAlarm(relativeOffset: 0)
        location.structuredLocation = EKStructuredLocation(title: "Office")
        location.proximity = .enter

        XCTAssertEqual(DueDateAlarm.alarmsToRemove(from: [tenMinutesBefore, absolute, location]), [])
    }
}
