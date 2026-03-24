import AVFoundation
import Foundation

final class PCM16MonoAudioCaptureService: NSObject {
    private let session = AVAudioSession.sharedInstance()

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?

    func permissionState() -> RecorderViewModel.MicrophonePermissionState {
        switch session.recordPermission {
        case .granted:
            return .granted
        case .denied:
            return .denied
        case .undetermined:
            return .undetermined
        @unknown default:
            return .undetermined
        }
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            session.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording() throws {
        guard recorder == nil else { return }

        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker, .duckOthers]
        )
        try session.setPreferredSampleRate(16_000)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let url = Self.makeRecordingURL()
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = false
        recorder.prepareToRecord()

        guard recorder.record() else {
            throw RecordingError.startFailed
        }

        self.recorder = recorder
        self.recordingURL = url
    }

    func stopRecording() throws -> URL {
        guard let recorder, let recordingURL else {
            throw RecordingError.missingRecording
        }

        recorder.stop()
        self.recorder = nil
        self.recordingURL = nil
        try? session.setActive(false, options: .notifyOthersOnDeactivation)

        return recordingURL
    }

    func cancelRecording() {
        recorder?.stop()
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }

        recorder = nil
        recordingURL = nil
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func makeRecordingURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "voicevibe-\(UUID().uuidString.lowercased()).wav")
    }
}

extension PCM16MonoAudioCaptureService {
    enum RecordingError: LocalizedError {
        case startFailed
        case missingRecording

        var errorDescription: String? {
            switch self {
            case .startFailed:
                return "无法开始录音。"
            case .missingRecording:
                return "当前没有可用的录音文件。"
            }
        }
    }
}
