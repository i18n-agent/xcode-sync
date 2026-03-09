import SwiftUI

struct MenuBarView: View {
    @Bindable var appState: AppState
    @Environment(\.openWindow) private var openWindow

    private let detector = XcodeProjectDetector()
    private let scanner = LocalizationScanner()
    private let cliBridge = CLIBridge()
    private let notifications = NotificationManager()

    var body: some View {
        let state = appState.project

        if let name = state.projectName {
            Text(name).disabled(true)
        } else {
            Text(String(localized: "noProject")).disabled(true)
        }

        Divider()

        Button(String(localized: "pullTranslations")) {
            detectProjectAndShowPicker()
        }
        .disabled(state.isSyncing)

        Button(String(localized: "pushTranslations")) {
            Task { await pushAll() }
        }
        .disabled(state.isSyncing)

        Divider()

        if state.isSyncing {
            Text(String(localized: "syncing")).disabled(true)
        } else if let lastSync = state.lastSync {
            if lastSync.isSuccess {
                Text(String(localized: "syncedLanguages \(lastSync.languageCount)")).disabled(true)
            } else {
                Text(lastSync.error ?? String(localized: "unknownError")).disabled(true)
            }
        }

        if cliBridge.findCLIPath() == nil {
            Text(String(localized: "cliNotInstalled")).disabled(true)
        } else if cliBridge.readApiKey() == nil {
            Text(String(localized: "noApiKey")).disabled(true)
        }

        Divider()

        Button(String(localized: "settings")) {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button(String(localized: "quit")) {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    // MARK: - Actions

    private func detectProjectAndShowPicker() {
        appState.project.isSyncing = true
        Task {
            defer { appState.project.isSyncing = false }
            do {
                let result = try detector.detectActiveProject()
                let scanResult = scanner.scan(
                    projectDir: result.projectDir,
                    xcodeprojPath: result.projectPath
                )
                appState.project.projectPath = result.projectDir
                appState.project.projectName = result.projectName
                appState.project.knownRegions = scanResult.knownRegions
                appState.project.developmentRegion = scanResult.developmentRegion
                appState.project.localizationFiles = scanResult.localizationFiles
                appState.project.isSyncing = false
                openWindow(id: "language-picker")
            } catch {
                appState.project.lastSync = SyncResult(operation: .pull, languageCount: 0, fileCount: 0, error: error.localizedDescription)
            }
        }
    }

    private func pushAll() async {
        do {
            let result = try detector.detectActiveProject()
            appState.project.projectPath = result.projectDir
            appState.project.projectName = result.projectName

            let scanResult = scanner.scan(
                projectDir: result.projectDir,
                xcodeprojPath: result.projectPath
            )
            appState.project.developmentRegion = scanResult.developmentRegion
            appState.project.knownRegions = scanResult.knownRegions
        } catch {
            appState.project.lastSync = SyncResult(operation: .push, languageCount: 0, fileCount: 0, error: error.localizedDescription)
            return
        }

        appState.project.isSyncing = true
        defer { appState.project.isSyncing = false }

        guard let projectDir = appState.project.projectPath else { return }
        let sourceLanguage = appState.project.developmentRegion ?? "en"
        let namespace = appState.project.projectName ?? "unknown"
        let targetRegions = appState.project.targetRegions

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
        appState.project.lastSync = syncResult
        notifications.send(for: syncResult, projectName: appState.project.projectName ?? "Project", projectDir: appState.project.projectPath)
    }
}
