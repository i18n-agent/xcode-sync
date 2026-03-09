import SwiftUI

struct SettingsView: View {
    private let cliBridge = CLIBridge()

    @State private var cliPath: String?
    @State private var maskedApiKey: String?

    var body: some View {
        Form {
            Section(String(localized: "cliConfiguration")) {
                LabeledContent(String(localized: "cliPath")) {
                    Text(cliPath ?? String(localized: "notFound"))
                        .foregroundColor(cliPath != nil ? .primary : .red)
                }

                LabeledContent(String(localized: "configFile")) {
                    Text("~/.config/i18nagent/config.json")
                        .font(.caption)
                }

                LabeledContent(String(localized: "apiKey")) {
                    Text(maskedApiKey ?? String(localized: "notConfigured"))
                        .foregroundColor(maskedApiKey != nil ? .primary : .orange)
                }
            }

            Section {
                if cliPath == nil {
                    Text(String(localized: "installCLIHint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if maskedApiKey == nil {
                    Text(String(localized: "loginHint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button(String(localized: "openConfigFolder")) {
                    let configDir = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent(".config/i18nagent")
                    NSWorkspace.shared.open(configDir)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 250)
        .onAppear {
            cliPath = cliBridge.findCLIPath()
            maskedApiKey = cliBridge.maskApiKey(cliBridge.readApiKey())
        }
    }
}
