import Foundation
import SwiftUI

@Observable
final class ProjectState {
    var projectName: String?
    var projectPath: String?
    var knownRegions: [String] = []
    var developmentRegion: String?
    var localizationFiles: [LocalizationFile] = []
    var isSyncing: Bool = false
    var lastSync: SyncResult?

    var targetRegions: [String] {
        guard let dev = developmentRegion else { return knownRegions }
        return knownRegions.filter { $0 != dev && $0 != "Base" }
    }

    var hasProject: Bool { projectPath != nil }
}
