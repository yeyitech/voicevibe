import Foundation

enum SharedRecorderCommandAction: String, Codable {
    case start
    case stop
}

struct SharedRecorderCommand: Codable, Equatable {
    let id: String
    let action: SharedRecorderCommandAction
    let createdAt: Date

    init(id: String = UUID().uuidString.lowercased(), action: SharedRecorderCommandAction, createdAt: Date = Date()) {
        self.id = id
        self.action = action
        self.createdAt = createdAt
    }
}
