import SwiftUI

@main
struct i18nAgentApp: App {
    var body: some Scene {
        MenuBarExtra("i18n Agent", systemImage: "globe") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
