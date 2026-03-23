import AVFAudio
import Foundation

final class MacAudioCaptureService {
    private let engine = AVAudioEngine()
    private let bufferLock = NSLock()

    private let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16_000,
        channels: 1,
        interleaved: true
    )!

    private var isCapturing = false
    private var recordingBuffer = Data()

    func permissionState() -> PermissionState {
        switch AVAudioApplication.shared.recordPermission {
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
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startCapture() throws {
        guard !isCapturing else { return }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        bufferLock.lock()
        recordingBuffer = Data()
        bufferLock.unlock()

        let framesPerBuffer = AVAudioFrameCount(max(1_024, Int(inputFormat.sampleRate / 10)))
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: framesPerBuffer, format: inputFormat) { [weak self, outputFormat] buffer, _ in
            guard
                let self,
                let audioData = Self.convert(buffer: buffer, outputFormat: outputFormat)
            else {
                return
            }

            self.bufferLock.lock()
            self.recordingBuffer.append(audioData)
            self.bufferLock.unlock()
        }

        engine.prepare()
        try engine.start()
        isCapturing = true
    }

    func stopCapture() -> Data {
        if isCapturing {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            isCapturing = false
        }

        bufferLock.lock()
        let finalData = recordingBuffer
        recordingBuffer = Data()
        bufferLock.unlock()
        return finalData
    }

    func cancelCapture() {
        if isCapturing {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            isCapturing = false
        }
        bufferLock.lock()
        recordingBuffer = Data()
        bufferLock.unlock()
    }

    func saveAsWAVFile(_ audioData: Data) -> URL? {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "typeless_\(UUID().uuidString.lowercased()).wav"
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        let sampleRate: UInt32 = 16_000
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = sampleRate * UInt32(numChannels) * UInt32(bitsPerSample) / 8
        let blockAlign = numChannels * bitsPerSample / 8
        let dataSize = UInt32(audioData.count)
        let fileSize = dataSize + 36

        var header = Data()
        header.append("RIFF".data(using: .ascii)!)
        header.append(Data(from: fileSize))
        header.append("WAVE".data(using: .ascii)!)
        header.append("fmt ".data(using: .ascii)!)
        header.append(Data(from: UInt32(16)))
        header.append(Data(from: UInt16(1)))
        header.append(Data(from: numChannels))
        header.append(Data(from: sampleRate))
        header.append(Data(from: byteRate))
        header.append(Data(from: blockAlign))
        header.append(Data(from: bitsPerSample))
        header.append("data".data(using: .ascii)!)
        header.append(Data(from: dataSize))

        do {
            try (header + audioData).write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }

    private static func convert(
        buffer: AVAudioPCMBuffer,
        outputFormat: AVAudioFormat
    ) -> Data? {
        guard let converter = AVAudioConverter(from: buffer.format, to: outputFormat) else {
            return nil
        }

        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1

        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            return nil
        }

        var sourceBuffer: AVAudioPCMBuffer? = buffer
        var conversionError: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if let currentBuffer = sourceBuffer {
                outStatus.pointee = .haveData
                sourceBuffer = nil
                return currentBuffer
            }

            outStatus.pointee = .endOfStream
            return nil
        }

        converter.convert(to: convertedBuffer, error: &conversionError, withInputFrom: inputBlock)

        guard conversionError == nil else { return nil }
        guard let channelData = convertedBuffer.int16ChannelData else { return nil }

        let frameLength = Int(convertedBuffer.frameLength)
        let bytesPerFrame = Int(outputFormat.streamDescription.pointee.mBytesPerFrame)
        return Data(bytes: channelData[0], count: frameLength * bytesPerFrame)
    }
}

private enum AudioCaptureError: LocalizedError {
    case converterUnavailable

    var errorDescription: String? {
        switch self {
        case .converterUnavailable:
            return "无法创建音频格式转换器。"
        }
    }
}

private extension Data {
    init<T>(from value: T) {
        var mutableValue = value
        self = Swift.withUnsafeBytes(of: &mutableValue) { Data($0) }
    }
}
