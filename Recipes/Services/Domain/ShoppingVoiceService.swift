import AVFoundation
import Speech

// MARK: - Shopping Voice Service

/// Audio-based guided shopping experience.
/// Reads the grocery list section by section, item by item,
/// and waits for voice confirmation before proceeding.
/// ShoppingVoiceService is the single source of truth for all session state.
@Observable
@MainActor
final class ShoppingVoiceService: NSObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?

    var isListening = false
    var isSpeaking = false
    private(set) var isMuted = false
    private var speechFinishedContinuation: AsyncStream<Void>.Continuation?
    /// Identifies the current speak() call so stale cancelled-task cleanup
    /// doesn't wipe the continuation that belongs to the next speak() call.
    private var speakToken: UUID?
    var lastHeardText: String?
    var currentItemName: String?

    // MARK: - Callbacks

    /// Called on MainActor whenever an item is marked as found.
    /// The view uses this to add food items to the pantry.
    var onItemFound: ((GroceryItem) -> Void)?

    // MARK: - Session State

    private(set) var sortedSections: [(StoreSection, [GroceryItem])] = []
    private(set) var currentSectionIndex = 0
    private(set) var currentItemIndex = 0
    private(set) var isActive = false
    private(set) var isComplete = false
    private var voiceEnabled = false
    private var guidanceTask: Task<Void, Never>?

    // MARK: - Computed State

    var currentItem: GroceryItem? {
        guard currentSectionIndex < sortedSections.count else { return nil }
        let unpurchased = sortedSections[currentSectionIndex].1.filter { !$0.isPurchased }
        guard !unpurchased.isEmpty else { return nil }
        // Clamp the index in case items were purchased externally, shifting the array shorter.
        let safeIndex = min(currentItemIndex, unpurchased.count - 1)
        return unpurchased[safeIndex]
    }

    var currentSection: StoreSection? {
        guard currentSectionIndex < sortedSections.count else { return nil }
        return sortedSections[currentSectionIndex].0
    }

    var totalItems: Int { sortedSections.flatMap { $0.1 }.count }
    var purchasedItems: Int { sortedSections.flatMap { $0.1 }.filter(\.isPurchased).count }

    override init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        super.init()
        self.synthesizer.delegate = self
    }

    deinit {
        // Swift 6: deinit is nonisolated, so we can't touch AVSpeechSynthesizer
        // directly. Capture the synthesizer (not self) in a MainActor Task to
        // nil the delegate and break the retain cycle.
        let synth = synthesizer
        Task { @MainActor in synth.delegate = nil }
    }

    // MARK: - Session Control

    func startSession(list: GroceryList, voiceEnabled: Bool) {
        stopSession()
        self.voiceEnabled = voiceEnabled
        self.sortedSections = list.itemsBySection
            .sorted { $0.key.sortOrder < $1.key.sortOrder }
            .filter { !$0.value.allSatisfy(\.isPurchased) }
        self.currentSectionIndex = 0
        self.currentItemIndex = 0
        self.isComplete = false
        self.isActive = true

        if voiceEnabled {
            guidanceTask = Task { await runVoiceGuidance() }
        }
    }

    func stopSession() {
        guidanceTask?.cancel()
        guidanceTask = nil
        stopSpeaking()
        stopListening()
        isActive = false
        isComplete = false
    }

    func markFound() {
        if let item = currentItem {
            onItemFound?(item)
            item.isPurchased = true
        }
        // The purchased item drops out of the unpurchased filtered list, so the
        // next item slides into currentItemIndex automatically. Do NOT increment —
        // just check whether the section is now exhausted.
        advanceSectionIfExhausted()
        restartGuidanceIfNeeded()
    }

    func skip() {
        // Explicitly move past the current item without purchasing it.
        advanceToNextItem()
        restartGuidanceIfNeeded()
    }

    // MARK: - Private Navigation

    /// Called after marking an item purchased. The index stays the same;
    /// only move to the next section if the current one is fully done.
    private func advanceSectionIfExhausted() {
        guard currentSectionIndex < sortedSections.count else {
            isComplete = true
            return
        }
        let remaining = sortedSections[currentSectionIndex].1.filter { !$0.isPurchased }
        guard remaining.isEmpty || currentItemIndex >= remaining.count else { return }
        currentSectionIndex += 1
        currentItemIndex = 0
        if currentSectionIndex >= sortedSections.count {
            isComplete = true
        }
    }

    /// Called when skipping an item. Increments the index to move past it.
    private func advanceToNextItem() {
        guard currentSectionIndex < sortedSections.count else {
            isComplete = true
            return
        }
        let unpurchased = sortedSections[currentSectionIndex].1.filter { !$0.isPurchased }
        if unpurchased.count > 1 && currentItemIndex < unpurchased.count - 1 {
            currentItemIndex += 1
        } else {
            currentSectionIndex += 1
            currentItemIndex = 0
        }
        if currentSectionIndex >= sortedSections.count {
            isComplete = true
        }
    }

    private func restartGuidanceIfNeeded() {
        guard voiceEnabled, !isComplete else { return }
        guidanceTask?.cancel()
        guidanceTask = Task { await runVoiceGuidance() }
    }

    private func runVoiceGuidance() async {
        guard let item = currentItem else {
            if isComplete { await speak("Shopping complete! All done.") }
            return
        }

        let prompt = item.formattedAmount.map { "\($0) of \(item.name)" } ?? item.name
        await speak("\(prompt). Did you find it?")
        guard !Task.isCancelled else { return }

        let response = await listenForConfirmation()
        guard !Task.isCancelled else { return }

        switch response {
        case .yes:
            await speak("Got it.")
            markFound()
        case .no, .cantFind:
            await speak("No worries, keeping it on the list.")
            skip()
        case .substitute:
            await speak("I'll flag that for substitution.")
            // View will show substitution sheet — just advance
            skip()
        case .skip:
            await speak("Skipping.")
            skip()
        case .done:
            await speak("Finishing up.")
            stopSession()
        case .error:
            await speak("I didn't catch that. Moving on.")
            skip()
        }
    }

    // MARK: - Text-to-Speech

    func toggleMute() {
        isMuted.toggle()
    }

    func speak(_ text: String) async {
        // Return immediately when muted — guidance loop continues, user uses buttons.
        guard !isMuted else { return }

        stopListening()
        // Stop any in-progress speech so a fresh call doesn't queue behind it.
        stopSpeaking()

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .voicePrompt, options: .duckOthers)
        try? AVAudioSession.sharedInstance().setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        // Stamp this invocation so the cleanup below doesn't clobber a newer
        // speak() call's continuation. If this task is cancelled and a new
        // speak() starts before our cleanup runs, the new call's token differs
        // and we skip the nil-assignment that would orphan its continuation.
        let myToken = UUID()
        speakToken = myToken

        isSpeaking = true
        synthesizer.speak(utterance)

        let stream = AsyncStream<Void> { continuation in
            self.speechFinishedContinuation = continuation
        }
        for await _ in stream {
            break
        }
        // Only clear the shared continuation if we still own it.
        if speakToken == myToken {
            speechFinishedContinuation = nil
        }
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
            // Signal the waiting speak() call that speech is done.
            speechFinishedContinuation?.yield()
            speechFinishedContinuation?.finish()
        }
    }

    /// Fired when stopSpeaking(at:) cancels an in-flight utterance.
    /// We must NOT yield here — speak() already called stopSpeaking() which
    /// finished the old continuation. Yielding again would unblock the *new*
    /// speak() call's continuation prematurely.
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
            // Do not yield/finish — stopSpeaking() already closed the old stream.
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
