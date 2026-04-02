import Speech
import AVFoundation

// MARK: - Speech Recognizer Service

/// Wraps SFSpeechRecognizer + AVAudioEngine for real-time transcription.
/// Automatically stops after a configurable silence interval.
@Observable
@MainActor
final class SpeechRecognizer {

    var transcript = ""
    var isListening = false
    var error: String?

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: .current)
    private var silenceTimer: Timer?
    private let silenceTimeout: TimeInterval = 2.0

    // MARK: - Public API

    func start() async {
        guard await requestPermissions() else {
            error = "Speech recognition permission is required. Enable it in Settings."
            return
        }
        do {
            try beginListening()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func stop() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Private

    // nonisolated: SFSpeechRecognizer and AVAudioApplication callbacks fire on
    // background threads. Keeping this off @MainActor avoids the isolation
    // assertion that would crash when the continuation resumes off-main.
    private nonisolated func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speechStatus == .authorized else { return false }

        let micStatus = AVAudioApplication.shared.recordPermission
        if micStatus == .undetermined {
            return await AVAudioApplication.requestRecordPermission()
        }
        return micStatus == .granted
    }

    private func beginListening() throws {
        transcript = ""
        error = nil

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest,
              let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw SpeechError.unavailable
        }
        request.shouldReportPartialResults = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, err in
            // Callback fires on a background thread — hop to MainActor before
            // touching any @Observable state or starting timers.
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    self.resetSilenceTimer()
                }
                if err != nil || result?.isFinal == true {
                    self.stop()
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true
        resetSilenceTimer()
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }
    }

    enum SpeechError: Error, LocalizedError {
        case unavailable
        var errorDescription: String? { "Speech recognition is not available right now." }
    }
}
