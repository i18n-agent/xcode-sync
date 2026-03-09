import Foundation

final class CLIBridge {
    private let configPath: String

    struct TranslateResult {
        let jobId: String
        let outputDir: String?
        let filesWritten: [String]
    }

    struct UploadResult {
        let pairsStored: Int
        let pairsUpdated: Int
    }

    enum CLIError: LocalizedError {
        case cliNotFound
        case executionFailed(String)
        case parseError(String)
        case apiError(String)

        var errorDescription: String? {
            switch self {
            case .cliNotFound:
                String(localized: "cliNotFound")
            case .executionFailed(let msg):
                String(localized: "executionFailed \(msg)")
            case .parseError(let msg):
                String(localized: "parseError \(msg)")
            case .apiError(let msg):
                msg
            }
        }
    }

    init(configPath: String? = nil) {
        self.configPath = configPath ?? {
            let home = FileManager.default.homeDirectoryForCurrentUser
            return home.appendingPathComponent(".config/i18nagent/config.json").path
        }()
    }

    // MARK: - Config

    func readApiKey() -> String? {
        guard let data = FileManager.default.contents(atPath: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let key = json["apiKey"] as? String else {
            return nil
        }
        return key
    }

    func maskApiKey(_ key: String?) -> String? {
        guard let key, key.count > 4 else {
            return key != nil ? "****" : nil
        }
        let suffix = String(key.suffix(4))
        let prefix = key.hasPrefix("i18n_") ? "i18n_" : ""
        return "\(prefix)****\(suffix)"
    }

    // MARK: - CLI Detection

    func findCLIPath() -> String? {
        let candidates = [
            "/usr/local/bin/i18nagent",
            "/opt/homebrew/bin/i18nagent",
        ]

        if let path = runSync(executablePath: "/usr/bin/which", arguments: ["i18nagent"]) {
            let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        for candidate in candidates {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        return nil
    }

    // MARK: - Command Building

    func buildTranslateArgs(filePath: String, languages: [String], namespace: String, outputDir: String) -> [String] {
        [
            "translate", filePath,
            "--lang", languages.joined(separator: ","),
            "--namespace", namespace,
            "--output", outputDir,
            "--json"
        ]
    }

    func buildUploadArgs(filePath: String, sourceLanguage: String, targetLanguage: String, namespace: String) -> [String] {
        [
            "upload", filePath,
            "--source", sourceLanguage,
            "--target", targetLanguage,
            "--namespace", namespace,
            "--json"
        ]
    }

    // MARK: - Execution

    func runTranslate(filePath: String, languages: [String], namespace: String, outputDir: String) async throws -> TranslateResult {
        guard let cliPath = findCLIPath() else { throw CLIError.cliNotFound }
        let args = buildTranslateArgs(filePath: filePath, languages: languages, namespace: namespace, outputDir: outputDir)
        let output = try await run(executablePath: cliPath, arguments: args)
        return try parseTranslateResult(output)
    }

    func runUpload(filePath: String, sourceLanguage: String, targetLanguage: String, namespace: String) async throws -> UploadResult {
        guard let cliPath = findCLIPath() else { throw CLIError.cliNotFound }
        let args = buildUploadArgs(filePath: filePath, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage, namespace: namespace)
        let output = try await run(executablePath: cliPath, arguments: args)
        return try parseUploadResult(output)
    }

    // MARK: - Parsing

    func parseTranslateResult(_ jsonString: String) throws -> TranslateResult {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CLIError.parseError("Invalid JSON")
        }
        if let error = json["error"] as? String {
            throw CLIError.apiError(error)
        }
        guard let jobId = json["jobId"] as? String else {
            throw CLIError.parseError("Missing jobId")
        }
        let outputDir = json["outputDir"] as? String
        let filesWritten = json["filesWritten"] as? [String] ?? []
        return TranslateResult(jobId: jobId, outputDir: outputDir, filesWritten: filesWritten)
    }

    func parseUploadResult(_ jsonString: String) throws -> UploadResult {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CLIError.parseError("Invalid JSON")
        }
        if let error = json["error"] as? String {
            throw CLIError.apiError(error)
        }
        let stored = json["pairsStored"] as? Int ?? 0
        let updated = json["pairsUpdated"] as? Int ?? 0
        return UploadResult(pairsStored: stored, pairsUpdated: updated)
    }

    // MARK: - Process Execution

    private func run(executablePath: String, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executablePath)
                process.arguments = arguments

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: CLIError.executionFailed(error.localizedDescription))
                    return
                }

                // Read pipes BEFORE waitUntilExit to avoid deadlock when
                // the child process fills the pipe buffer.
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                if process.terminationStatus != 0 {
                    let errorMsg = stderr.isEmpty ? "Exit code \(process.terminationStatus)" : stderr
                    continuation.resume(throwing: CLIError.executionFailed(errorMsg.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    continuation.resume(returning: stdout)
                }
            }
        }
    }

    private func runSync(executablePath: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
