import ArgumentParser
@preconcurrency import EventKit
import Foundation

// MARK: - Hidden Completion Helper

extension ReminderCLI {
    struct CompleteIDs: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "_complete-ids",
            abstract: "Internal command for shell completion",
            shouldDisplay: false
        )

        mutating func run() async throws {
            let store = ReminderStore()

            do {
                try await store.requestAccess()
                let reminders = try await store.getAllReminders()

                // Output short IDs (one per line) for completion
                for reminder in reminders {
                    let shortID = String(reminder.calendarItemIdentifier.prefix(8))
                    let title = reminder.title ?? "(no title)"
                    // Format: ID\tTitle (tab-separated for description)
                    print("\(shortID)\t\(title)")
                }
            } catch {
                // Silently fail - completion will just show no results
            }
        }
    }
}

@main
struct ReminderCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reminder-cli",
        abstract: "A CLI tool to manage iCloud Reminders",
        version: "1.2.0-dot",
        subcommands: [
            List.self,
            Show.self,
            Create.self,
            Update.self,
            Delete.self,
            Complete.self,
            Lists.self,
            CompleteIDs.self
        ]
    )
}

// MARK: - Recurrence Option Validation

/// Rejects end conditions that EventKit would silently ignore or crash on
/// (EKRecurrenceEnd(occurrenceCount:) raises an Objective-C exception for counts below 1).
func validateRecurrenceOptions(recurrence: String?, recurrenceEnd: String?, recurrenceCount: Int?) throws {
    if recurrence == nil && (recurrenceEnd != nil || recurrenceCount != nil) {
        throw ValidationError("--recurrence-end and --recurrence-count require --recurrence")
    }
    if recurrenceEnd != nil && recurrenceCount != nil {
        throw ValidationError("--recurrence-end and --recurrence-count cannot be used together")
    }
    if let count = recurrenceCount, count < 1 {
        throw ValidationError("--recurrence-count must be 1 or greater")
    }
}

// MARK: - Sort Option

enum SortOption: String, ExpressibleByArgument {
    case dueDate = "due-date"
    case priority = "priority"
    case title = "title"
    case created = "created"
    case status = "status"
}

// MARK: - List Command
extension ReminderCLI {
    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List all reminders or reminders in a specific list"
        )

        @Argument(help: "The name of the list to show reminders from")
        var listName: String?

        @Flag(name: .shortAndLong, help: "Show completed reminders")
        var completed: Bool = false

        @Option(name: .shortAndLong, help: "Output format (text, json, pretty-json, yaml)")
        var format: OutputFormat = .text

        @Option(name: .shortAndLong, help: "Sort order (due-date, priority, title, created, status)")
        var sort: SortOption = .dueDate

        mutating func run() async throws {
            let store = ReminderStore()
            try await store.requestAccess()

            if let listName = listName {
                try await store.listReminders(in: listName, showCompleted: completed, format: format, sortBy: sort)
            } else {
                try await store.listAllReminders(showCompleted: completed, format: format, sortBy: sort)
            }
        }
    }
}

// MARK: - Show Command
extension ReminderCLI {
    struct Show: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show details of a specific reminder"
        )

        @Argument(
            help: "The ID (full UUID or short prefix) of the reminder to show",
            completion: .custom { _, _, _ in
                // Call the hidden subcommand to get completion candidates
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["reminder-cli", "_complete-ids"]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = nil

                do {
                    try process.run()
                    process.waitUntilExit()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        let shell = ProcessInfo.processInfo.environment["SAP_SHELL"] ?? "zsh"

                        return output.split(separator: "\n").map { line in
                            let parts = line.split(separator: "\t", maxSplits: 1)
                            if parts.count == 2 {
                                // fish uses tab-separated format, zsh uses colon
                                if shell == "fish" {
                                    return "\(parts[0])\t\(parts[1])"
                                } else {
                                    return "\(parts[0]):\(parts[1])"
                                }
                            }
                            return String(parts[0])
                        }
                    }
                } catch {
                    // Silently fail
                }

                return []
            }
        )
        var identifier: String

        @Option(name: .shortAndLong, help: "Output format (text, json, pretty-json, yaml)")
        var format: OutputFormat = .text

        mutating func run() async throws {
            let store = ReminderStore()
            try await store.requestAccess()
            try await store.showReminder(identifier: identifier, format: format)
        }
    }
}

// MARK: - Lists Command Group
extension ReminderCLI {
    struct Lists: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List, create, and delete reminder lists",
            discussion: "Running `reminder-cli lists` without a subcommand lists all reminder lists (same as `lists list`).",
            subcommands: [ListAll.self, Create.self, Delete.self],
            defaultSubcommand: ListAll.self
        )

        struct ListAll: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                commandName: "list",
                abstract: "List all reminder lists"
            )

            @Flag(name: .shortAndLong, help: "Include reminder count per list (all reminders, including completed; slower)")
            var count: Bool = false

            @Option(name: .shortAndLong, help: "Output format (text, json, pretty-json, yaml)")
            var format: OutputFormat = .text

            mutating func run() async throws {
                let store = ReminderStore()
                try await store.requestAccess()
                try await store.listCalendars(includeCount: count, format: format)
            }
        }

        struct Create: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Create a new reminder list"
            )

            @Argument(help: "The name of the list to create")
            var name: String

            @Option(name: .shortAndLong, help: "Output format (text, json, pretty-json, yaml)")
            var format: OutputFormat = .text

            mutating func run() async throws {
                let store = ReminderStore()
                try await store.requestAccess()
                try store.createList(name: name, format: format)
            }
        }

        struct Delete: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Delete a reminder list and all of its reminders",
                discussion: "The list can be given by name (case-insensitive) or by calendarIdentifier. If several lists share the same name, use the calendarIdentifier."
            )

            @Argument(help: "The name or calendarIdentifier of the list to delete")
            var list: String

            @Flag(name: .shortAndLong, help: "Skip confirmation")
            var force: Bool = false

            @Option(name: .long, help: "Output format (text, json, pretty-json, yaml)")
            var format: OutputFormat = .text

            mutating func run() async throws {
                let store = ReminderStore()
                try await store.requestAccess()
                try await store.deleteList(list, force: force, format: format)
            }
        }
    }
}

// MARK: - Create Command
extension ReminderCLI {
    struct Create: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Create a new reminder"
        )

        @Argument(help: "The title of the reminder")
        var title: String

        @Option(name: .shortAndLong, help: "The list to add the reminder to")
        var list: String?

        @Option(name: .shortAndLong, help: "Notes for the reminder")
        var notes: String?

        @Option(help: "Start date (format: YYYY-MM-DD or YYYY-MM-DD HH:MM)")
        var startDate: String?

        @Option(help: "Due date (format: YYYY-MM-DD or YYYY-MM-DD HH:MM)")
        var dueDate: String?

        @Option(name: .shortAndLong, help: "Priority (0-9, where 0=none, 1-4=high, 5=medium, 6-9=low)")
        var priority: Int?

        @Option(name: .shortAndLong, help: "URL associated with the reminder")
        var url: String?

        @Option(name: .shortAndLong, help: "Recurrence rule (daily, weekly, monthly, yearly, \"every N days/weeks\", \"weekly:mon,wed,fri\")")
        var recurrence: String?

        @Option(help: "Recurrence end date (format: YYYY-MM-DD)")
        var recurrenceEnd: String?

        @Option(help: "Number of occurrences before recurrence ends")
        var recurrenceCount: Int?

        @Option(name: .shortAndLong, help: "Output format (text, json, pretty-json, yaml)")
        var format: OutputFormat = .text

        func validate() throws {
            try validateRecurrenceOptions(
                recurrence: recurrence, recurrenceEnd: recurrenceEnd, recurrenceCount: recurrenceCount
            )
        }

        mutating func run() async throws {
            let store = ReminderStore()
            try await store.requestAccess()
            try await store.createReminder(
                title: title,
                listName: list,
                notes: notes,
                startDate: startDate,
                dueDate: dueDate,
                priority: priority,
                url: url,
                recurrence: recurrence,
                recurrenceEnd: recurrenceEnd,
                recurrenceCount: recurrenceCount,
                format: format
            )
        }
    }
}

// MARK: - Update Command
extension ReminderCLI {
    struct Update: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Update an existing reminder"
        )

        @Argument(
            help: "The ID (full UUID or short prefix) of the reminder to update",
            completion: .custom { _, _, _ in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["reminder-cli", "_complete-ids"]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = nil
                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        let shell = ProcessInfo.processInfo.environment["SAP_SHELL"] ?? "zsh"

                        return output.split(separator: "\n").map { line in
                            let parts = line.split(separator: "\t", maxSplits: 1)
                            if parts.count == 2 {
                                if shell == "fish" {
                                    return "\(parts[0])\t\(parts[1])"
                                } else {
                                    return "\(parts[0]):\(parts[1])"
                                }
                            }
                            return String(parts[0])
                        }
                    }
                } catch {}
                return []
            }
        )
        var identifier: String

        @Option(name: .shortAndLong, help: "New title")
        var title: String?

        @Option(name: .shortAndLong, help: "New notes")
        var notes: String?

        @Option(help: "New start date (format: YYYY-MM-DD or YYYY-MM-DD HH:MM)")
        var startDate: String?

        @Option(help: "New due date (format: YYYY-MM-DD or YYYY-MM-DD HH:MM)")
        var dueDate: String?

        @Option(name: .shortAndLong, help: "New priority (0-9)")
        var priority: Int?

        @Option(name: .shortAndLong, help: "New URL")
        var url: String?

        @Option(name: .shortAndLong, help: "Move to a different list")
        var list: String?

        @Option(name: .shortAndLong, help: "Recurrence rule (daily, weekly, monthly, yearly, \"every N days/weeks\", \"weekly:mon,wed,fri\")")
        var recurrence: String?

        @Option(help: "Recurrence end date (format: YYYY-MM-DD)")
        var recurrenceEnd: String?

        @Option(help: "Number of occurrences before recurrence ends")
        var recurrenceCount: Int?

        @Flag(help: "Remove recurrence from the reminder")
        var noRecurrence: Bool = false

        @Option(name: .shortAndLong, help: "Output format (text, json, pretty-json, yaml)")
        var format: OutputFormat = .text

        func validate() throws {
            if noRecurrence && recurrence != nil {
                throw ValidationError("--recurrence and --no-recurrence cannot be used together")
            }
            try validateRecurrenceOptions(
                recurrence: recurrence, recurrenceEnd: recurrenceEnd, recurrenceCount: recurrenceCount
            )
        }

        mutating func run() async throws {
            let store = ReminderStore()
            try await store.requestAccess()
            try await store.updateReminder(
                identifier: identifier,
                title: title,
                notes: notes,
                startDate: startDate,
                dueDate: dueDate,
                priority: priority,
                url: url,
                listName: list,
                recurrence: recurrence,
                recurrenceEnd: recurrenceEnd,
                recurrenceCount: recurrenceCount,
                noRecurrence: noRecurrence,
                format: format
            )
        }
    }
}

// MARK: - Delete Command
extension ReminderCLI {
    struct Delete: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Delete a reminder"
        )

        @Argument(
            help: "The ID (full UUID or short prefix) of the reminder to delete",
            completion: .custom { _, _, _ in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["reminder-cli", "_complete-ids"]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = nil
                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        let shell = ProcessInfo.processInfo.environment["SAP_SHELL"] ?? "zsh"

                        return output.split(separator: "\n").map { line in
                            let parts = line.split(separator: "\t", maxSplits: 1)
                            if parts.count == 2 {
                                if shell == "fish" {
                                    return "\(parts[0])\t\(parts[1])"
                                } else {
                                    return "\(parts[0]):\(parts[1])"
                                }
                            }
                            return String(parts[0])
                        }
                    }
                } catch {}
                return []
            }
        )
        var identifier: String

        @Flag(name: .shortAndLong, help: "Skip confirmation")
        var force: Bool = false

        @Option(name: .long, help: "Output format (text, json, pretty-json, yaml)")
        var format: OutputFormat = .text

        mutating func run() async throws {
            let store = ReminderStore()
            try await store.requestAccess()
            try await store.deleteReminder(identifier: identifier, force: force, format: format)
        }
    }
}

// MARK: - Complete Command
extension ReminderCLI {
    struct Complete: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Mark a reminder as completed"
        )

        @Argument(
            help: "The ID (full UUID or short prefix) of the reminder to complete",
            completion: .custom { _, _, _ in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["reminder-cli", "_complete-ids"]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = nil
                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        let shell = ProcessInfo.processInfo.environment["SAP_SHELL"] ?? "zsh"

                        return output.split(separator: "\n").map { line in
                            let parts = line.split(separator: "\t", maxSplits: 1)
                            if parts.count == 2 {
                                if shell == "fish" {
                                    return "\(parts[0])\t\(parts[1])"
                                } else {
                                    return "\(parts[0]):\(parts[1])"
                                }
                            }
                            return String(parts[0])
                        }
                    }
                } catch {}
                return []
            }
        )
        var identifier: String

        @Option(name: .shortAndLong, help: "Output format (text, json, pretty-json, yaml)")
        var format: OutputFormat = .text

        mutating func run() async throws {
            let store = ReminderStore()
            try await store.requestAccess()
            try await store.completeReminder(identifier: identifier, format: format)
        }
    }
}
