import XCTest
@testable import i18nAgent

final class ModelsTests: XCTestCase {

    func testLocalizationFileInit() {
        let file = LocalizationFile(
            sourcePath: "/path/to/Base.lproj/Localizable.strings",
            format: .strings,
            baseName: "Localizable.strings"
        )
        XCTAssertEqual(file.sourcePath, "/path/to/Base.lproj/Localizable.strings")
        XCTAssertEqual(file.format, .strings)
        XCTAssertEqual(file.baseName, "Localizable.strings")
    }

    func testLocalizationFileFormats() {
        XCTAssertEqual(LocalizationFile.Format.strings.fileExtension, "strings")
        XCTAssertEqual(LocalizationFile.Format.xcstrings.fileExtension, "xcstrings")
        XCTAssertEqual(LocalizationFile.Format.stringsdict.fileExtension, "stringsdict")
        XCTAssertEqual(LocalizationFile.Format.storyboard.fileExtension, "storyboard")
        XCTAssertEqual(LocalizationFile.Format.xib.fileExtension, "xib")
    }

    func testSyncResultSuccess() {
        let result = SyncResult(
            operation: .pull,
            languageCount: 3,
            fileCount: 2,
            error: nil
        )
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.operation, .pull)
        XCTAssertEqual(result.languageCount, 3)
    }

    func testSyncResultFailure() {
        let result = SyncResult(
            operation: .push,
            languageCount: 0,
            fileCount: 0,
            error: "No API key"
        )
        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(result.error, "No API key")
    }

    func testSyncResultNotificationTitle() {
        let pullResult = SyncResult(operation: .pull, languageCount: 3, fileCount: 2, error: nil)
        XCTAssertTrue(pullResult.notificationTitle.contains("3"))

        let pushResult = SyncResult(operation: .push, languageCount: 5, fileCount: 3, error: nil)
        XCTAssertTrue(pushResult.notificationTitle.contains("5"))
    }

    func testProjectStateInitialValues() {
        let state = ProjectState()
        XCTAssertNil(state.projectName)
        XCTAssertNil(state.projectPath)
        XCTAssertTrue(state.knownRegions.isEmpty)
        XCTAssertNil(state.developmentRegion)
        XCTAssertTrue(state.localizationFiles.isEmpty)
        XCTAssertFalse(state.isSyncing)
        XCTAssertNil(state.lastSync)
    }

    func testTargetRegionsExcludesDevelopmentAndBase() {
        let state = ProjectState()
        state.knownRegions = ["en", "Base", "ja", "de", "es"]
        state.developmentRegion = "en"
        XCTAssertEqual(state.targetRegions, ["ja", "de", "es"])
    }
}
