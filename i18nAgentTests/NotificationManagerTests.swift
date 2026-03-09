import XCTest
@testable import i18nAgent

final class NotificationManagerTests: XCTestCase {

    func testBuildNotificationContentForPullSuccess() {
        let manager = NotificationManager()
        let result = SyncResult(operation: .pull, languageCount: 3, fileCount: 2, error: nil)
        let content = manager.buildNotificationContent(for: result, projectName: "MyApp")
        XCTAssertTrue(content.title.contains("MyApp"))
        XCTAssertTrue(content.body.contains("3"))
    }

    func testBuildNotificationContentForPushSuccess() {
        let manager = NotificationManager()
        let result = SyncResult(operation: .push, languageCount: 5, fileCount: 3, error: nil)
        let content = manager.buildNotificationContent(for: result, projectName: "TestApp")
        XCTAssertTrue(content.title.contains("TestApp"))
        XCTAssertTrue(content.body.contains("5"))
    }

    func testBuildNotificationContentForError() {
        let manager = NotificationManager()
        let result = SyncResult(operation: .pull, languageCount: 0, fileCount: 0, error: "No API key")
        let content = manager.buildNotificationContent(for: result, projectName: "MyApp")
        XCTAssertTrue(content.body.contains("No API key"))
    }
}
