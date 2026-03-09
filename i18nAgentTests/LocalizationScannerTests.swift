import XCTest
@testable import i18nAgent

final class LocalizationScannerTests: XCTestCase {

    let samplePbxproj = """
    developmentRegion = en;
    knownRegions = (
        en,
        Base,
        ja,
        de,
        es,
        fr,
    );
    """

    func testParseKnownRegions() {
        let scanner = LocalizationScanner()
        let regions = scanner.parseKnownRegions(from: samplePbxproj)
        XCTAssertEqual(regions, ["en", "Base", "ja", "de", "es", "fr"])
    }

    func testParseDevelopmentRegion() {
        let scanner = LocalizationScanner()
        let region = scanner.parseDevelopmentRegion(from: samplePbxproj)
        XCTAssertEqual(region, "en")
    }

    func testParseKnownRegionsEmpty() {
        let scanner = LocalizationScanner()
        let regions = scanner.parseKnownRegions(from: "no regions here")
        XCTAssertTrue(regions.isEmpty)
    }

    func testFindLocalizationFilesInDirectory() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let baseLproj = tmpDir.appendingPathComponent("Base.lproj")
        try FileManager.default.createDirectory(at: baseLproj, withIntermediateDirectories: true)
        try "/* strings */".write(to: baseLproj.appendingPathComponent("Localizable.strings"), atomically: true, encoding: .utf8)

        let enLproj = tmpDir.appendingPathComponent("en.lproj")
        try FileManager.default.createDirectory(at: enLproj, withIntermediateDirectories: true)
        try "/* strings */".write(to: enLproj.appendingPathComponent("Localizable.strings"), atomically: true, encoding: .utf8)

        try "{}".write(to: tmpDir.appendingPathComponent("Localizable.xcstrings"), atomically: true, encoding: .utf8)

        let scanner = LocalizationScanner()
        let files = scanner.findLocalizationFiles(in: tmpDir.path)

        XCTAssertTrue(files.contains { $0.format == .strings && $0.baseName == "Localizable.strings" })
        XCTAssertTrue(files.contains { $0.format == .xcstrings && $0.baseName == "Localizable.xcstrings" })
    }

    func testFindLprojDirectories() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        for lang in ["Base", "en", "ja", "de"] {
            let lproj = tmpDir.appendingPathComponent("\(lang).lproj")
            try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
            try "test".write(to: lproj.appendingPathComponent("Localizable.strings"), atomically: true, encoding: .utf8)
        }

        let scanner = LocalizationScanner()
        let lprojMap = scanner.findLprojDirectories(in: tmpDir.path)

        XCTAssertEqual(lprojMap.count, 4)
        XCTAssertNotNil(lprojMap["en"])
        XCTAssertNotNil(lprojMap["ja"])
        XCTAssertNotNil(lprojMap["Base"])
    }
}
