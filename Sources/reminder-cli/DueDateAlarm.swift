@preconcurrency import EventKit
import Foundation

/// EventKit-independent rules for the alarm that accompanies a timed due date.
/// EventKit doesn't notify on dueDate alone, so a timed due date gets an explicit alarm.
enum DueDateAlarm {
    static func needsAlarm(for dueDate: DateComponents) -> Bool {
        dueDate.hour != nil
    }

    static func alarmsToRemove(from alarms: [EKAlarm], newDueDate: DateComponents) -> [EKAlarm] {
        if needsAlarm(for: newDueDate) {
            // Replaced by a fresh at-due-time alarm, so repeated updates don't stack duplicates
            return alarms
        }
        // Only the at-due-time alarm depends on the due time; location, absolute,
        // and offset alarms are user-defined and stay meaningful without it
        return alarms.filter(isAtDueTime)
    }

    private static func isAtDueTime(_ alarm: EKAlarm) -> Bool {
        alarm.structuredLocation == nil && alarm.absoluteDate == nil && alarm.relativeOffset == 0
    }
}
