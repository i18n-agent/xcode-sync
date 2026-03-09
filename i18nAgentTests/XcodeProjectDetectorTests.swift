import XCTest
@testable import i18nAgent

final class XcodeProjectDetectorTests: XCTestCase {

    func testExtractProjectNameFromPath() {
        let detector = XcodeProjectDetector()
        XCTAssertEqual(detector.extractProjectName(from: "/Users/dev/MyApp/MyApp.xcodeproj"), "MyApp")
        XCTAssertEqual(detector.extractProjectName(from: "/Users/dev/MyApp/MyApp.xcworkspace"), "MyApp")
        XCTAssertEqual(detector.extractProjectName(from: "/Users/dev/SomeProject"), "SomeProject")
    }

    func testExtractProjectDirFromXcodeproj() {
        let detector = XcodeProjectDetector()
        XCTAssertEqual(detector.extractProjectDir(from: "/Users/dev/MyApp/MyApp.xcodeproj"), "/Users/dev/MyApp")
        XCTAssertEqual(detector.extractProjectDir(from: "/Users/dev/MyApp/MyApp.xcworkspace"), "/Users/dev/MyApp")
    }

    func testFindXcodeprojInDirectory() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let xcodeproj = tmpDir.appendingPathComponent("TestApp.xcodeproj")
        try FileManager.default.createDirectory(at: xcodeproj, withIntermediateDirectories: true)

        let detector = XcodeProjectDetector()
        let found = detector.findXcodeproj(in: tmpDir.path)
        XCTAssertNotNil(found)
        XCTAssertTrue(found!.hasSuffix("TestApp.xcodeproj"))
    }

    func testFindXcodeprojReturnsNilWhenMissing() {
        let detector = XcodeProjectDetector()
        let found = detector.findXcodeproj(in: "/tmp/empty-dir-\(UUID().uuidString)")
        XCTAssertNil(found)
    }
}
