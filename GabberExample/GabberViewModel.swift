import Foundation
import Gabber
import Combine
import AVFoundation

class GabberViewModel: ObservableObject, GabberDelegate {
    @Published var messages: [SessionMessage] = []
    @Published var inputMessage: String = ""
    @Published var connectionState: ConnectionState = .notConnected
    @Published var agentState: AgentState = .warmup
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var microphoneEnabled: Bool = false
    @Published var remainingSeconds: Float?
    @Published var agentVolume: (bands: [Float], volume: Float) = ([], 0)
    @Published var userVolume: (bands: [Float], volume: Float) = ([], 0)
    
    private var gabber: Gabber?
    private var cancellables: Set<AnyCancellable> = []
    
    func fetchConnectionDetails() {
        checkMicrophonePermission()
        isLoading = true
        error = nil
        print("Fetching connection details...")
        
        guard let url = URL(string: "http://localhost:3000/start-session") else {
            print("Invalid server URL")
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = ["userId": "user123"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody, options: [])
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            if let error = error {
                print("Error fetching session data: \(error)")
                DispatchQueue.main.async {
                    self.error = "Failed to start session"
                }
                return
            }
            
            guard let data = data else {
                print("No data received")
                return
            }
            
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let sessionUrl = jsonResponse["url"] as? String,
                   let sessionToken = jsonResponse["token"] as? String {
                    print("Session URL: \(sessionUrl)")
                    print("Session Token: \(sessionToken.prefix(10))...")
                    
                    let connectionDetails = ConnectionDetails(url: sessionUrl, token: sessionToken)
                    DispatchQueue.main.async {
                        self.connect(connectionDetails: connectionDetails)
                    }
                } else {
                    print("Invalid JSON response")
                }
            } catch {
                print("Error parsing JSON: \(error)")
            }
        }.resume()
    }
    
    func connect(connectionDetails: ConnectionDetails) {
        print("Attempting to connect with details: \(connectionDetails)")
        gabber = Gabber(connectionDetails: connectionDetails, delegate: self)
        
        Task {
            do {
                print("Calling gabber.connect()")
                try await gabber?.connect()
                print("Connection successful")
                DispatchQueue.main.async {
                    self.connectionState = .connected
                    self.checkGabberState()
                }
            } catch {
                print("Error while trying to connect to the session: \(error)")
                DispatchQueue.main.async {
                    self.error = "Connection error: \(error.localizedDescription)"
                    self.connectionState = .notConnected
                }
            }
        }
    }
    
    func sendMessage() {
        guard let gabber = gabber, !inputMessage.isEmpty else {
            print("Message is empty or Gabber is nil")
            return
        }
        
        Task {
            do {
                print("Sending message: \(inputMessage)")
                try await gabber.sendChat(message: inputMessage)
                DispatchQueue.main.async {
                    self.inputMessage = ""
                }
            } catch {
                print("Error sending message: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.error = "Failed to send message: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func disconnect() {
        print("Disconnecting from session...")
        Task {
            do {
                try await gabber?.disconnect()
                print("Disconnected from session")
            } catch {
                print("Error disconnecting: \(error.localizedDescription)")
            }
        }
    }
    
    func toggleMicrophone() {
        guard let gabber = gabber else {
            print("Gabber instance is nil")
            return
        }
        
        Task {
            do {
                print("Toggling microphone. Current state: \(microphoneEnabled)")
                try await gabber.setMicrophone(enabled: !microphoneEnabled)
            } catch {
                print("Error toggling microphone: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.error = "Failed to toggle microphone: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func checkGabberState() {
        guard let gabber = gabber else {
            print("Gabber instance is nil")
            return
        }
        print("Gabber state checked")
        print("Connection state: \(connectionState)")
        print("Agent state: \(agentState)")
        print("Microphone enabled: \(microphoneEnabled)")
    }

    // MARK: - GabberDelegate methods
    
    func ConnectionStateChanged(state: ConnectionState) {
        print("ConnectionStateChanged: \(state)")
        DispatchQueue.main.async {
            self.connectionState = state
        }
    }
    
    func MessagesChanged(messages: [SessionMessage]) {
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
    
    func AgentStateChanged(_ state: AgentState) {
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
        DispatchQueue.main.async {
            self.error = "Agent Error: \(msg)"
        }
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
