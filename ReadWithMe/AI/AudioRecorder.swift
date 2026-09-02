import AVFoundation

/// Records a short microphone clip to a temp .m4a for dictation.
@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false

    private var recorder: AVAudioRecorder?
    private var fileURL: URL?

    /// Requests mic permission and starts recording. Returns false if denied.
    func start() async -> Bool {
        let granted = await withCheckedContinuation { cont in
            AVCaptureDevice.requestAccess(for: .audio) { cont.resume(returning: $0) }
        }
        guard granted else { return false }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dictation-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        do {
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.record()
            recorder = rec
            fileURL = url
            isRecording = true
            return true
        } catch {
            return false
        }
    }

    /// Stops recording and returns the file URL of the captured clip.
    func stop() -> URL? {
        recorder?.stop()
        recorder = nil
        isRecording = false
        return fileURL
    }
}
