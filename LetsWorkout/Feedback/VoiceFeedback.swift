import AVFoundation

final class VoiceFeedback {
    private let synthesizer = AVSpeechSynthesizer()
    private var lastSpokenTime: Date = .distantPast
    private let cooldownInterval: TimeInterval = 3.0

    func speak(_ text: String) {
        let now = Date()
        guard now.timeIntervalSince(lastSpokenTime) >= cooldownInterval else { return }
        lastSpokenTime = now

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.2
        utterance.volume = 0.8

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
