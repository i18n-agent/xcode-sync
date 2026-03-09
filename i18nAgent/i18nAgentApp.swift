import SwiftUI

@main
struct i18nAgentApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("i18n Agent", systemImage: "globe") {
            MenuBarView(appState: appState)
        }

        Window("i18n Agent Settings", id: "settings") {
            SettingsView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Window("Select Languages", id: "language-picker") {
            LanguagePickerWindow(appState: appState)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
