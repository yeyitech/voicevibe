import Foundation

enum SharedRecorderStatus: String, Codable {
    case idle
    case connecting
    case recording
    case processing
    case completed
    case error
}

struct SharedRecorderSnapshot: Codable, Equatable {
    let status: SharedRecorderStatus
    let liveTranscript: String
    let committedTranscript: String
    let latestResultID: String?
    let lastError: String?
    let updatedAt: Date

    static let empty = SharedRecorderSnapshot(
        status: .idle,
        liveTranscript: "",
        committedTranscript: "",
        latestResultID: nil,
        lastError: nil,
        updatedAt: .distantPast
    )
}
