import AVFoundation
import Speech

// MARK: - Shopping Voice Service

/// Audio-based guided shopping experience.
/// Reads the grocery list section by section, item by item,
/// and waits for voice confirmation before proceeding.
@Observable
final class ShoppingVoiceService: NSObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?

    var isListening = false
    var isSpeaking = false
    var lastHeardText: String?
    var currentItemName: String?

    override init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        super.init()
        self.synthesizer.delegate = self
    }

    // MARK: - Text-to-Speech

    func speak(_ text: String) async {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        isSpeaking = true
        synthesizer.speak(utterance)

        // Wait for speech to finish
        while isSpeaking {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
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

        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine
        let request = SFSpeechAudioBufferRecognitionRequest()

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()
        isListening = true

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<ShoppingResponse, Never>) in
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let result else {
                    if error != nil {
                        continuation.resume(returning: .error)
                    }
                    return
                }

                let text = result.bestTranscription.formattedString.lowercased()
                self?.lastHeardText = text

                if result.isFinal {
                    let response = Self.parseResponse(text)
                    continuation.resume(returning: response)
                }
            }
        }

        stopListening()
        return result
    }

    func stopListening() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        isListening = false
    }

    // MARK: - Guided Shopping Flow

    func guideShopping(list: GroceryList) async {
        let sections = list.itemsBySection.sorted { $0.key.rawValue < $1.key.rawValue }

        await speak("Let's start shopping. You have \(list.items.count) items across \(sections.count) sections.")

        for (section, items) in sections {
            let unpurchased = items.filter { !$0.isPurchased }
            guard !unpurchased.isEmpty else { continue }

            await speak("Moving to \(section.displayName). You need \(unpurchased.count) items here.")

            for item in unpurchased {
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

        await speak("Shopping complete! All sections covered.")
    }

    // MARK: - Parse Response

    private static func parseResponse(_ text: String) -> ShoppingResponse {
        let positiveWords = ["yes", "got it", "found it", "yep", "yeah", "check", "done"]
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
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
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
