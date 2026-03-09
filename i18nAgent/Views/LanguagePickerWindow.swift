import SwiftUI

struct LanguagePickerWindow: View {
    @Bindable var appState: AppState
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var selectedRegions: Set<String> = []

    private let cliBridge = CLIBridge()
    private let notifications = NotificationManager()

    var body: some View {
        let regions = appState.project.targetRegions

        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "selectLanguages"))
                .font(.headline)

            if regions.isEmpty {
                Text("No target languages found in project.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(regions, id: \.self) { region in
                            Toggle(isOn: binding(for: region)) {
                                Text(displayName(for: region))
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)

                Divider()

                HStack {
                    Button(String(localized: "selectAll")) {
                        selectedRegions = Set(regions)
                    }
                    .buttonStyle(.link)

                    Button(String(localized: "deselectAll")) {
                        selectedRegions = []
                    }
                    .buttonStyle(.link)

                    Spacer()

                    Button(String(localized: "cancel")) {
                        dismissWindow(id: "language-picker")
                    }
                    .keyboardShortcut(.cancelAction)

                    Button(String(localized: "translate")) {
                        let languages = Array(selectedRegions)
                        dismissWindow(id: "language-picker")
                        Task { await pullTranslations(languages: languages) }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedRegions.isEmpty)
                }
            }
        }
        .padding()
        .frame(width: 280)
        .onAppear {
            selectedRegions = Set(regions)
        }
    }

    private func binding(for region: String) -> Binding<Bool> {
        Binding(
            get: { selectedRegions.contains(region) },
            set: { isOn in
                if isOn {
                    selectedRegions.insert(region)
                } else {
                    selectedRegions.remove(region)
                }
            }
        )
    }

    private func displayName(for regionCode: String) -> String {
        let locale = Locale.current
        if let name = locale.localizedString(forIdentifier: regionCode) {
            return "\(name) (\(regionCode))"
        }
        return regionCode
    }

    private func pullTranslations(languages: [String]) async {
        appState.project.isSyncing = true
        defer { appState.project.isSyncing = false }

        guard let projectDir = appState.project.projectPath else { return }
        let namespace = appState.project.projectName ?? "unknown"

        let sourceFiles = appState.project.localizationFiles.filter { file in
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
        appState.project.lastSync = syncResult
        notifications.send(for: syncResult, projectName: appState.project.projectName ?? "Project", projectDir: appState.project.projectPath)
    }
}
