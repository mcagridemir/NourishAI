// Sana — VoiceInputService.swift
// Transcribes short speech bursts using SFSpeechRecognizer.
import Foundation
import Speech
import AVFoundation
internal import Combine

@MainActor
final class VoiceInputService: ObservableObject {

    static let shared = VoiceInputService()

    @Published var transcript: String = ""
    @Published var isListening: Bool = false
    @Published var error: String?
    @Published var isAvailable: Bool = false

    private var recognizer: SFSpeechRecognizer?
    private var audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private init() {
        recognizer = SFSpeechRecognizer(locale: .current)
        isAvailable = recognizer?.isAvailable ?? false
    }

    // MARK: - Permissions

    func requestPermission() async -> Bool {
        let speech = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        let audio: Bool
        if #available(iOS 17, *) {
            audio = await AVAudioApplication.requestRecordPermission()
        } else {
            audio = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
            }
        }
        return speech && audio
    }

    // MARK: - Start / Stop

    func startListening() {
        guard !isListening else { return }
        transcript = ""
        error = nil

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.error = "Microphone unavailable."
            return
        }

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { return }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        do { try audioEngine.start() } catch {
            self.error = "Audio engine failed to start."
            return
        }

        isListening = true

        task = recognizer?.recognitionTask(with: request) { [weak self] result, err in
            if let result {
                Task { @MainActor in self?.transcript = result.bestTranscription.formattedString }
            }
            if err != nil || result?.isFinal == true {
                Task { @MainActor in self?.stopListening() }
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
