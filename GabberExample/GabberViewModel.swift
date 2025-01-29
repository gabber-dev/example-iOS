import Foundation
import Gabber
import Combine
import AVFoundation

class GabberViewModel: ObservableObject, RealtimeSessionEngineDelegate {
    @Published var messages: [Components.Schemas.SDKSessionTranscription] = []
    @Published var inputMessage: String = ""
    @Published var connectionState: Components.Schemas.SDKConnectionState = .not_connected
    @Published var agentState: Components.Schemas.SDKAgentState = .warmup
    @Published var isLoading: Bool = false
    @Published var microphoneEnabled: Bool = false
    @Published var remainingSeconds: Float?
    @Published var agentVolume: (bands: [Float], volume: Float) = ([], 0)
    @Published var userVolume: (bands: [Float], volume: Float) = ([], 0)
    @Published var prompt: String = "You are a woman named Hilary working in the library."
    
    @Published var voices: [Components.Schemas.Voice] = []
    @Published var selectedVoiceId: String? = nil
    
    private var token: String? = nil
    
    private var llmId = "21892bb9-9809-4b6f-8c3e-e40093069f04"
    
    
    private lazy var session: RealtimeSessionEngine = {
        return RealtimeSessionEngine(delegate: self)
    }()
    
    private func generateToken() async throws -> String {
        print("Generating token")
        if let t = self.token {
            return t
        }
        
        // Define the URL for the token endpoint
        guard let url = URL(string: "http://localhost:4000/token") else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        // Prepare the URL request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        do {
            // Perform the network request
            let (data, _) = try await URLSession.shared.data(for: request)
            
            // Try to parse the JSON response
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["token"] as? String {
                print("Generated token \(token)")
                self.token = token
                return token
            } else {
                throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Token not found in response"])
            }
            
        } catch {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Network error: \(error.localizedDescription)"])
        }
    }
    
    func fetchVoices() async throws {
        print("Fetching voices")
        let token = try await generateToken()
        let api = Api.client(token: token)
        let voices = try await api.listVoices().ok.body.json.values
        if voices.count >= 0 {
            DispatchQueue.main.async {
                self.voices = voices
                self.selectedVoiceId = voices[0].id  // Set selectedVoiceID on the main thread
            }
        }
    }
    
    func connect() async throws {
        checkMicrophonePermission()
        let token = try await generateToken()
        let api = Api.client(token: token)
        let memoryContext = try await api.createContext(body: .json(.init(persona: nil, scenario: nil, messages: [.init(role: .system, content: prompt)]))).ok.body.json
        let config = Components.Schemas.RealtimeSessionConfigCreate(general: .init(save_messages: true), input: .init(interruptable: true, parallel_listening: true), generative: .init(llm: llmId, voice_override: selectedVoiceId, context: memoryContext.id), output: .init(stream_transcript: true, speech_synthesis_enabled: true))
        try await session.connect(opts: .case2(.init(token: token, config: config)))
    }
    
    func sendMessage() async throws {
        try await session.sendChat(message: inputMessage)
        DispatchQueue.main.async {
            self.inputMessage = ""
        }
    }
    
    func disconnect() {
        print("Disconnecting from session...")
        Task {
            do {
                try await session.disconnect()
                print("Disconnected from session")
            } catch {
                print("Error disconnecting: \(error.localizedDescription)")
            }
        }
    }
    
    func toggleMicrophone() async throws {
        try await session.setMicrophone(enabled: !microphoneEnabled)
    }
    
    func checkGabberState() {
        print("Gabber state checked")
        print("Connection state: \(connectionState)")
        print("Agent state: \(agentState)")
        print("Microphone enabled: \(microphoneEnabled)")
    }
    
    // MARK: - GabberDelegate methods
    
    func ConnectionStateChanged(state: Components.Schemas.SDKConnectionState) {
        print("ConnectionStateChanged: \(state)")
        DispatchQueue.main.async {
            self.connectionState = state
        }
    }
    
    func MessagesChanged(messages: [Components.Schemas.SDKSessionTranscription]) {
        print("MessagesChanged: \(messages)")
        DispatchQueue.main.async {
            self.messages = messages
        }
    }
    
    func MicrophoneStateChanged(enabled: Bool) {
        print("MicrophoneStateChanged: \(enabled)")
        DispatchQueue.main.async {
            self.microphoneEnabled = enabled
        }
    }
    
    func AgentStateChanged(_ state: Components.Schemas.SDKAgentState) {
        print("AgentStateChanged: \(state)")
        DispatchQueue.main.async {
            self.agentState = state
        }
    }
    
    func AgentVolumeChanged(bands: [Float], volume: Float) {
        print("AgentVolumeChanged: Volume: \(volume)")
        DispatchQueue.main.async {
            self.agentVolume = (bands, volume)
        }
    }
    
    func UserVolumeChanaged(bands: [Float], volume: Float) {
        print("UserVolumeChanaged: Volume: \(volume)")
        DispatchQueue.main.async {
            self.userVolume = (bands, volume)
        }
    }
    
    func RemainingSecondsChange(seconds: Float) {
        print("RemainingSecondsChange: \(seconds)")
        DispatchQueue.main.async {
            self.remainingSeconds = seconds
        }
    }
    
    func AgentError(msg: String) {
        print("AgentError: \(msg)")
    }
    
    func checkMicrophonePermission() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                print("Microphone permission granted")
            case .denied:
                print("Microphone permission denied")
            case .undetermined:
                print("Microphone permission not determined")
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    print("Microphone permission \(granted ? "granted" : "denied")")
                }
            @unknown default:
                print("Unknown microphone permission status")
            }
        } catch {
            print("Error setting up audio session: \(error.localizedDescription)")
        }
    }
}
