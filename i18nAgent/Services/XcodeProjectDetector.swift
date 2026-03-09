import Foundation

final class XcodeProjectDetector {

    struct DetectionResult {
        let projectPath: String
        let projectDir: String
        let projectName: String
    }

    enum DetectionError: LocalizedError {
        case xcodeNotRunning
        case noProjectOpen
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .xcodeNotRunning:
                String(localized: "xcodeNotRunning")
            case .noProjectOpen:
                String(localized: "noProjectOpen")
            case .permissionDenied:
                String(localized: "permissionDenied")
            }
        }
    }

    func detectActiveProject() throws -> DetectionResult {
        let script = """
        tell application "System Events"
            if not (exists process "Xcode") then
                error "Xcode is not running"
            end if
        end tell
        tell application "Xcode"
            set doc to active workspace document
            return path of doc
        end tell
        """

        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        guard let result = appleScript?.executeAndReturnError(&error) else {
            let errMsg = (error?["NSAppleScriptErrorMessage"] as? String) ?? "Unknown error"
            if errMsg.contains("not running") {
                throw DetectionError.xcodeNotRunning
            } else if errMsg.contains("Can't get") {
                throw DetectionError.noProjectOpen
            } else {
                throw DetectionError.permissionDenied
            }
        }

        let workspacePath = result.stringValue ?? ""
        let projectDir = extractProjectDir(from: workspacePath)
        let xcodeprojPath = findXcodeproj(in: projectDir) ?? workspacePath

        return DetectionResult(
            projectPath: xcodeprojPath,
            projectDir: projectDir,
            projectName: extractProjectName(from: workspacePath)
        )
    }

    func extractProjectName(from path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.deletingPathExtension().lastPathComponent
    }

    func extractProjectDir(from path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.deletingLastPathComponent().path
    }

    func findXcodeproj(in directoryPath: String) -> String? {
        let url = URL(fileURLWithPath: directoryPath)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            return nil
        }
        return contents.first { $0.pathExtension == "xcodeproj" }?.path
    }
}
