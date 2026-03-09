import SwiftUI

struct MenuBarView: View {
    @State private var state = ProjectState()
    @State private var showLanguagePicker = false
    @State private var cliPath: String?
    @State private var hasApiKey: Bool = false

    private let detector = XcodeProjectDetector()
    private let scanner = LocalizationScanner()
    private let cliBridge = CLIBridge()
    private let notifications = NotificationManager()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Project name header
            HStack {
                Image(systemName: "globe")
                Text(state.projectName ?? String(localized: "noProject"))
                    .font(.headline)
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            Divider()

            // Pull button
            Button {
                detectProjectAndShowPicker()
            } label: {
                Label(String(localized: "pullTranslations"), systemImage: "arrow.down.circle")
            }
            .disabled(state.isSyncing)

            // Push button
            Button {
                Task { await pushAll() }
            } label: {
                Label(String(localized: "pushTranslations"), systemImage: "arrow.up.circle")
            }
            .disabled(state.isSyncing)

            Divider()

            // Status
            if state.isSyncing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(String(localized: "syncing"))
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
            } else if let lastSync = state.lastSync {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "lastSync \(lastSync.timestamp.formatted(.relative(presentation: .named)))"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if lastSync.isSuccess {
                        Text(String(localized: "syncedLanguages \(lastSync.languageCount)"))
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text(lastSync.error ?? String(localized: "unknownError"))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 8)
            }

            // CLI status
            if cliPath == nil {
                Text(String(localized: "cliNotInstalled"))
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
            } else if !hasApiKey {
                Text(String(localized: "noApiKey"))
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
            }

            Divider()

            SettingsLink {
                Label(String(localized: "settings"), systemImage: "gear")
            }

            Button(String(localized: "quit")) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(.vertical, 4)
        .frame(width: 240)
        .onAppear {
            cliPath = cliBridge.findCLIPath()
            hasApiKey = cliBridge.readApiKey() != nil
        }
        .popover(isPresented: $showLanguagePicker) {
            LanguagePickerView(
                regions: state.targetRegions,
                onTranslate: { selectedLanguages in
                    showLanguagePicker = false
                    Task { await pullTranslations(languages: selectedLanguages) }
                },
                onCancel: { showLanguagePicker = false }
            )
        }
    }

    // MARK: - Actions

    private func detectProjectAndShowPicker() {
        state.isSyncing = true
        Task {
            defer { state.isSyncing = false }
            do {
                let result = try detector.detectActiveProject()
                let scanResult = scanner.scan(
                    projectDir: result.projectDir,
                    xcodeprojPath: result.projectPath
                )
                state.projectPath = result.projectDir
                state.projectName = result.projectName
                state.knownRegions = scanResult.knownRegions
                state.developmentRegion = scanResult.developmentRegion
                state.localizationFiles = scanResult.localizationFiles
                state.isSyncing = false
                showLanguagePicker = true
            } catch {
                state.lastSync = SyncResult(operation: .pull, languageCount: 0, fileCount: 0, error: error.localizedDescription)
            }
        }
    }

    private func pullTranslations(languages: [String]) async {
        state.isSyncing = true
        defer { state.isSyncing = false }

        guard let projectDir = state.projectPath else { return }
        let namespace = state.projectName ?? "unknown"

        let sourceFiles = state.localizationFiles.filter { file in
            file.format == .strings || file.format == .xcstrings || file.format == .stringsdict
        }

        var totalFiles = 0
        var lastError: String?

        for file in sourceFiles {
            let outputDir = NSTemporaryDirectory() + "i18nagent-\(UUID().uuidString)"
            do {
                let result = try await cliBridge.runTranslate(
                    filePath: file.sourcePath,
                    languages: languages,
                    namespace: namespace,
                    outputDir: outputDir
                )
                for writtenFile in result.filesWritten {
                    let lang = URL(fileURLWithPath: writtenFile).deletingPathExtension().lastPathComponent
                    let lprojDir = projectDir + "/\(lang).lproj"
                    try? FileManager.default.createDirectory(atPath: lprojDir, withIntermediateDirectories: true)
                    let dest = lprojDir + "/\(file.baseName)"
                    try? FileManager.default.removeItem(atPath: dest)
                    try FileManager.default.copyItem(atPath: writtenFile, toPath: dest)
                    totalFiles += 1
                }
                try? FileManager.default.removeItem(atPath: outputDir)
            } catch {
                lastError = error.localizedDescription
            }
        }

        let syncResult = SyncResult(
            operation: .pull,
            languageCount: languages.count,
            fileCount: totalFiles,
            error: lastError
        )
        state.lastSync = syncResult
        notifications.send(for: syncResult, projectName: state.projectName ?? "Project", projectDir: state.projectPath)
    }

    private func pushAll() async {
        do {
            let result = try detector.detectActiveProject()
            state.projectPath = result.projectDir
            state.projectName = result.projectName

            let scanResult = scanner.scan(
                projectDir: result.projectDir,
                xcodeprojPath: result.projectPath
            )
            state.developmentRegion = scanResult.developmentRegion
            state.knownRegions = scanResult.knownRegions
        } catch {
            state.lastSync = SyncResult(operation: .push, languageCount: 0, fileCount: 0, error: error.localizedDescription)
            return
        }

        state.isSyncing = true
        defer { state.isSyncing = false }

        guard let projectDir = state.projectPath else { return }
        let sourceLanguage = state.developmentRegion ?? "en"
        let namespace = state.projectName ?? "unknown"
        let targetRegions = state.targetRegions

        var totalPairs = 0
        var lastError: String?

        for lang in targetRegions {
            let lprojDir = projectDir + "/\(lang).lproj"
            guard FileManager.default.fileExists(atPath: lprojDir) else { continue }

            let files = (try? FileManager.default.contentsOfDirectory(atPath: lprojDir)) ?? []
            for file in files {
                let ext = (file as NSString).pathExtension
                guard ["strings", "stringsdict"].contains(ext) else { continue }

                let filePath = lprojDir + "/\(file)"
                do {
                    _ = try await cliBridge.runUpload(
                        filePath: filePath,
                        sourceLanguage: sourceLanguage,
                        targetLanguage: lang,
                        namespace: namespace
                    )
                    totalPairs += 1
                } catch {
                    lastError = error.localizedDescription
                }
            }
        }

        let syncResult = SyncResult(
            operation: .push,
            languageCount: targetRegions.count,
            fileCount: totalPairs,
            error: lastError
        )
        state.lastSync = syncResult
        notifications.send(for: syncResult, projectName: state.projectName ?? "Project", projectDir: state.projectPath)
    }
}
