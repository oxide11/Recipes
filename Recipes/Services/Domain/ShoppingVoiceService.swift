import AVFoundation
import Speech

// MARK: - Shopping Voice Service

/// Audio-based guided shopping experience.
/// Reads the grocery list section by section, item by item,
/// and waits for voice confirmation before proceeding.
@Observable
@MainActor
final class ShoppingVoiceService: NSObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?

    var isListening = false
    var isSpeaking = false
    private var speechFinishedContinuation: AsyncStream<Void>.Continuation?
    var lastHeardText: String?
    var currentItemName: String?

    override init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        super.init()
        self.synthesizer.delegate = self
    }

    // MARK: - Text-to-Speech

    func speak(_ text: String) async {
        stopListening()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .voicePrompt, options: .duckOthers)
        try? AVAudioSession.sharedInstance().setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        isSpeaking = true
        synthesizer.speak(utterance)

        // Wait for speech to finish using an async stream instead of polling
        let stream = AsyncStream<Void> { continuation in
            self.speechFinishedContinuation = continuation
        }
        for await _ in stream {
            break
        }
        speechFinishedContinuation = nil
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        speechFinishedContinuation?.finish()
    }

    // MARK: - Speech Recognition

    func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func listenForConfirmation() async -> ShoppingResponse {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            return .error
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            return .error
        }

        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine
        let request = SFSpeechAudioBufferRecognitionRequest()

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        let format = inputNode.outputFormat(forBus: 0)
        // The tap block must be nonisolated — AVAudioEngine fires it on
        // RealtimeMessenger.mServiceQueue, not the main actor. A closure
        // created inside a @MainActor method inherits that isolation and
        // causes a dispatch_assert_queue crash at runtime.
        let tapBlock = Self.makeTapBlock(for: request)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format, block: tapBlock)

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            return .error
        }
        isListening = true

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<ShoppingResponse, Never>) in
            var hasResumed = false
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self, !hasResumed else { return }
                    if let result {
                        self.lastHeardText = result.bestTranscription.formattedString.lowercased()
                        if result.isFinal {
                            hasResumed = true
                            let response = Self.parseResponse(self.lastHeardText ?? "")
                            continuation.resume(returning: response)
                        }
                    } else if error != nil {
                        hasResumed = true
                        continuation.resume(returning: .error)
                    }
                }
            }
        }

        stopListening()
        return result
    }

    func stopListening() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Guided Shopping Flow

    func guideShopping(list: GroceryList) async {
        let sections = list.itemsBySection.sorted { $0.key.rawValue < $1.key.rawValue }

        await speak("Let's start shopping. You have \(list.items.count) items across \(sections.count) sections.")

        for (section, items) in sections {
            guard !Task.isCancelled else { break }
            let unpurchased = items.filter { !$0.isPurchased }
            guard !unpurchased.isEmpty else { continue }

            await speak("Moving to \(section.displayName). You need \(unpurchased.count) items here.")

            for item in unpurchased {
                guard !Task.isCancelled else { break }
                currentItemName = item.name
                let amount = "\(item.quantity) \(item.unit.rawValue)"
                await speak("\(amount) of \(item.name). Did you find it?")

                let response = await listenForConfirmation()

                switch response {
                case .yes:
                    item.isPurchased = true
                    await speak("Got it.")
                case .no, .cantFind:
                    await speak("No worries. I'll keep it on the list for substitution.")
                case .substitute:
                    await speak("I'll suggest a substitution for \(item.name).")
                case .skip:
                    await speak("Skipping \(item.name).")
                case .done:
                    await speak("Finishing shopping session.")
                    return
                case .error:
                    await speak("I didn't catch that. Moving on.")
                }
            }
        }

        if Task.isCancelled {
            stopSpeaking()
            stopListening()
        } else {
            await speak("Shopping complete! All sections covered.")
        }
    }

    // MARK: - Audio Tap

    /// Returns a tap block with no actor isolation. Must be `nonisolated` and
    /// `static` so the returned closure is not bound to @MainActor — the
    /// AVAudioEngine tap fires on RealtimeMessenger.mServiceQueue and Swift's
    /// runtime isolation checker will crash if the block carries @MainActor.
    private nonisolated static func makeTapBlock(
        for request: SFSpeechAudioBufferRecognitionRequest
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in request.append(buffer) }
    }

    // MARK: - Parse Response

    private static func parseResponse(_ text: String) -> ShoppingResponse {
        let positiveWords = ["yes", "got it", "found it", "yep", "yeah", "check"]
        let negativeWords = ["no", "nope", "can't find", "not here", "don't see"]
        let substituteWords = ["substitute", "replace", "swap", "alternative"]
        let skipWords = ["skip", "next", "move on", "pass"]
        let doneWords = ["done", "finish", "stop", "that's all", "all done"]

        if doneWords.contains(where: text.contains) { return .done }
        if substituteWords.contains(where: text.contains) { return .substitute }
        if skipWords.contains(where: text.contains) { return .skip }
        if positiveWords.contains(where: text.contains) { return .yes }
        if negativeWords.contains(where: text.contains) { return .cantFind }

        return .error
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension ShoppingVoiceService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
            speechFinishedContinuation?.yield()
            speechFinishedContinuation?.finish()
        }
    }
}

// MARK: - Shopping Response

enum ShoppingResponse {
    case yes
    case no
    case cantFind
    case substitute
    case skip
    case done
    case error
}
