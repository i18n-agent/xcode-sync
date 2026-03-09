import Foundation

struct SyncResult {
    enum Operation {
        case pull
        case push
    }

    let operation: Operation
    let languageCount: Int
    let fileCount: Int
    let error: String?
    let timestamp: Date

    var isSuccess: Bool { error == nil }

    var notificationTitle: String {
        if let error {
            return String(localized: "syncFailed \(error)")
        }
        switch operation {
        case .pull:
            return String(localized: "pullComplete \(languageCount)")
        case .push:
            return String(localized: "pushComplete \(languageCount)")
        }
    }

    init(operation: Operation, languageCount: Int, fileCount: Int, error: String?, timestamp: Date = .now) {
        self.operation = operation
        self.languageCount = languageCount
        self.fileCount = fileCount
        self.error = error
        self.timestamp = timestamp
    }
}
