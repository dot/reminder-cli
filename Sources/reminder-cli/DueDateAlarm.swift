@preconcurrency import EventKit
import Foundation

/// EventKit-independent rules for the alarm that accompanies a timed due date.
/// EventKit doesn't notify on dueDate alone, so a timed due date gets an explicit alarm.
enum DueDateAlarm {
    static func needsAlarm(for dueDate: DateComponents) -> Bool {
        dueDate.hour != nil
    }

    /// Alarms to drop whenever the due date changes. Only the at-due-time alarm is managed:
    /// it is re-added for a timed due date (so repeated updates don't stack duplicates) and
    /// is meaningless without a time. Location, absolute, and offset alarms are user-defined.
    static func alarmsToRemove(from alarms: [EKAlarm]) -> [EKAlarm] {
        alarms.filter(isAtDueTime)
    }

    private static func isAtDueTime(_ alarm: EKAlarm) -> Bool {
        alarm.structuredLocation == nil && alarm.absoluteDate == nil && alarm.relativeOffset == 0
    }
}
