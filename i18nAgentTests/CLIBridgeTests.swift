import XCTest
@testable import i18nAgent

final class CLIBridgeTests: XCTestCase {

    func testReadConfigParsesApiKey() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let configFile = tmpDir.appendingPathComponent("config.json")
        let json = #"{"apiKey": "i18n_test123"}"#
        try json.write(to: configFile, atomically: true, encoding: .utf8)

        let bridge = CLIBridge(configPath: configFile.path)
        let apiKey = bridge.readApiKey()
        XCTAssertEqual(apiKey, "i18n_test123")
    }

    func testReadConfigReturnsNilWhenMissing() {
        let bridge = CLIBridge(configPath: "/nonexistent/config.json")
        XCTAssertNil(bridge.readApiKey())
    }

    func testMaskedApiKey() {
        let bridge = CLIBridge()
        XCTAssertEqual(bridge.maskApiKey("i18n_abcdefgh1234"), "i18n_****1234")
        XCTAssertEqual(bridge.maskApiKey("abcd"), "****")
        XCTAssertNil(bridge.maskApiKey(nil))
    }

    func testFindCLIPath() {
        let bridge = CLIBridge()
        let path = bridge.findCLIPath()
        if let path {
            XCTAssertTrue(path.contains("i18nagent"))
        }
    }

    func testBuildTranslateCommand() {
        let bridge = CLIBridge()
        let args = bridge.buildTranslateArgs(
            filePath: "/path/to/Localizable.strings",
            languages: ["ja", "de", "es"],
            namespace: "my-app",
            outputDir: "/tmp/output"
        )
        XCTAssertTrue(args.contains("translate"))
        XCTAssertTrue(args.contains("/path/to/Localizable.strings"))
        XCTAssertTrue(args.contains("--lang"))
        XCTAssertTrue(args.contains("ja,de,es"))
        XCTAssertTrue(args.contains("--namespace"))
        XCTAssertTrue(args.contains("my-app"))
        XCTAssertTrue(args.contains("--output"))
        XCTAssertTrue(args.contains("/tmp/output"))
        XCTAssertTrue(args.contains("--json"))
    }

    func testBuildUploadCommand() {
        let bridge = CLIBridge()
        let args = bridge.buildUploadArgs(
            filePath: "/path/to/ja.lproj/Localizable.strings",
            sourceLanguage: "en",
            targetLanguage: "ja",
            namespace: "my-app"
        )
        XCTAssertTrue(args.contains("upload"))
        XCTAssertTrue(args.contains("/path/to/ja.lproj/Localizable.strings"))
        XCTAssertTrue(args.contains("--source"))
        XCTAssertTrue(args.contains("en"))
        XCTAssertTrue(args.contains("--target"))
        XCTAssertTrue(args.contains("ja"))
        XCTAssertTrue(args.contains("--namespace"))
        XCTAssertTrue(args.contains("my-app"))
        XCTAssertTrue(args.contains("--json"))
    }

    func testParseTranslateResult() throws {
        let json = """
        {"jobId": "abc-123", "outputDir": "/tmp/out", "filesWritten": ["/tmp/out/ja.strings", "/tmp/out/de.strings"]}
        """
        let bridge = CLIBridge()
        let result = try bridge.parseTranslateResult(json)
        XCTAssertEqual(result.jobId, "abc-123")
        XCTAssertEqual(result.filesWritten.count, 2)
    }

    func testParseUploadResult() throws {
        let json = """
        {"pairsStored": 42, "pairsUpdated": 3}
        """
        let bridge = CLIBridge()
        let result = try bridge.parseUploadResult(json)
        XCTAssertEqual(result.pairsStored, 42)
        XCTAssertEqual(result.pairsUpdated, 3)
    }

    func testParseErrorResult() {
        let json = """
        {"error": "No API key found"}
        """
        let bridge = CLIBridge()
        XCTAssertThrowsError(try bridge.parseTranslateResult(json))
    }
}
