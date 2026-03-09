import Foundation
import SwiftUI

@Observable
final class AppState {
    var project = ProjectState()
    var showLanguagePicker = false
    var pendingPullLanguages: [String] = []
}
