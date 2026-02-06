import XCTest
@testable import reminder_cli

final class DateParserTests: XCTestCase {
    func testParsesDateOnly() throws {
        let components = try DateParser.parseDateComponents(from: "2026-01-15")

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 15)
        XCTAssertNil(components.hour)
        XCTAssertNil(components.minute)
    }

    func testParsesDateTime() throws {
        let components = try DateParser.parseDateComponents(from: "2026-01-15 14:30")

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 14)
        XCTAssertEqual(components.minute, 30)
    }

    func testInvalidFormatThrows() {
        XCTAssertThrowsError(try DateParser.parseDateComponents(from: "2026/01/15")) { error in
            guard case ReminderStoreError.invalidDateFormat = error else {
                return XCTFail("Expected invalidDateFormat error, got: \(error)")
            }
        }
    }
}
