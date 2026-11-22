@preconcurrency import EventKit
import XCTest
@testable import reminder_cli

final class DueDateAlarmTests: XCTestCase {
    private let dateOnly = DateComponents(year: 2026, month: 12, day: 3)
    private let timed = DateComponents(year: 2026, month: 12, day: 3, hour: 9, minute: 0)

    func testTimedDueDateNeedsAlarm() {
        XCTAssertTrue(DueDateAlarm.needsAlarm(for: timed))
    }

    func testDateOnlyDueDateDoesNotNeedAlarm() {
        XCTAssertFalse(DueDateAlarm.needsAlarm(for: dateOnly))
    }

    func testChangingToDateOnlyDueDropsAtDueTimeAlarm() {
        let atDueTime = EKAlarm(relativeOffset: 0)
        let removed = DueDateAlarm.alarmsToRemove(from: [atDueTime], newDueDate: dateOnly)
        XCTAssertEqual(removed, [atDueTime])
    }

    func testChangingToDateOnlyDueKeepsUserDefinedAlarms() {
        let tenMinutesBefore = EKAlarm(relativeOffset: -600)
        let absolute = EKAlarm(absoluteDate: Date(timeIntervalSince1970: 1_800_000_000))
        let location = EKAlarm(relativeOffset: 0)
        location.structuredLocation = EKStructuredLocation(title: "Office")
        location.proximity = .enter

        let removed = DueDateAlarm.alarmsToRemove(
            from: [tenMinutesBefore, absolute, location],
            newDueDate: dateOnly
        )
        XCTAssertEqual(removed, [])
    }

    func testChangingToTimedDueReplacesAllAlarms() {
        let atDueTime = EKAlarm(relativeOffset: 0)
        let tenMinutesBefore = EKAlarm(relativeOffset: -600)
        let removed = DueDateAlarm.alarmsToRemove(from: [atDueTime, tenMinutesBefore], newDueDate: timed)
        XCTAssertEqual(removed, [atDueTime, tenMinutesBefore])
    }
}
