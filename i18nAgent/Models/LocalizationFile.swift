import Foundation

struct LocalizationFile: Identifiable, Equatable {
    var id: String { sourcePath }
    let sourcePath: String
    let format: Format
    let baseName: String

    static func == (lhs: LocalizationFile, rhs: LocalizationFile) -> Bool {
        lhs.sourcePath == rhs.sourcePath && lhs.format == rhs.format && lhs.baseName == rhs.baseName
    }

    enum Format: String, CaseIterable {
        case strings
        case xcstrings
        case stringsdict
        case storyboard
        case xib

        var fileExtension: String { rawValue }
    }
}
