import Foundation
import SwiftUI
import AVFoundation
import Gabber

class GabberViewModel: ObservableObject {
    @Published var connectionState: ConnectionState = .notConnected
    @Published var errorMsg: String = ""
    @Published var agentState: AgentState = .warmup
    
    private var gabber: Gabber?
    
    // Function to fetch session details from your server
    func startSession() {
        // Request microphone permission before starting session
        requestMicrophonePermission()
        
        guard let url = URL(string: "http://localhost:3000/start-session") else {
            print("Invalid server URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = ["userId": "user123"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody, options: [])
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching session data: \(error)")
                DispatchQueue.main.async {
                    self.errorMsg = "Failed to start session"
                }
                return
            }
            
            guard let data = data else {
                print("No data received")
                return
            }
            
            // Parse the response to get URL and token
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let sessionUrl = jsonResponse["url"] as? String,
                   let sessionToken = jsonResponse["token"] as? String {
                    print("Session URL: \(sessionUrl)")
                    print("Session Token: \(sessionToken)")
                    
                    // Initialize Gabber with the fetched details
                    DispatchQueue.main.async {
                        self.setupGabber(with: sessionUrl, token: sessionToken)
                    }
                } else {
                    print("Invalid JSON response")
                }
            } catch {
                print("Error parsing JSON: \(error)")
            }
        }.resume()
        
        Task {
            do {
                try await self.gabber?.connect()
                print("Gabber connected successfully")
                DispatchQueue.main.async {
                    self.connectionState = .connected
                    
                }
            } catch {
                print("Error while trying to connect to the session: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMsg = "Failed to connect"
                    self.connectionState = .notConnected  // Update UI with the disconnected state
                }
            }
        }
    }
    
    // Function to initialize Gabber with URL and token
    func setupGabber(with url: String, token: String) {
        func configureAudioSession() {
            let audioSession = AVAudioSession.sharedInstance()
            do {
                // Set category for play and record, suitable for voice chat and ensuring speaker output
                try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker])
                
                // Activate the audio session
                try audioSession.setActive(true)
                
                print("Basic audio session configured successfully.")
            } catch {
                print("Failed to configure and activate audio session: \(error)")
            }
        }
    }
    
    // Configure the audio session
    func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Simplified audio session configuration
            try audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            
            print("Basic audio session configured successfully.")
        } catch {
            print("Failed to configure and activate audio session: \(error)")
        }
    }

    
    // Request microphone permission
    func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if granted {
                print("Microphone permission granted.")
            } else {
                print("Microphone permission denied.")
            }
        }
    }
}

// GabberDelegate Methods
extension GabberViewModel: GabberDelegate {
    func ConnectionStateChanged(state: ConnectionState) {
        print("Connection state changed to: \(state)")  // Log state changes
        DispatchQueue.main.async {
            self.connectionState = state
        }
    }

    func MessagesChanged(messages: [SessionMessage]) {
        // Handle message changes
    }

    func MicrophoneStateChanged(enabled: Bool) {
        // Handle microphone state changes
    }

    func AgentStateChanged(_ state: AgentState) {
        DispatchQueue.main.async {
            self.agentState = state
        }
    }

    func AgentVolumeChanged(bands: [Float], volume: Float) {
        // Handle agent volume changes
    }

    func UserVolumeChanaged(bands: [Float], volume: Float) {
        // Handle user volume changes
    }

    func RemainingSecondsChange(seconds: Float) {
        // Handle remaining seconds change
    }

    func AgentError(msg: String) {
        DispatchQueue.main.async {
            self.errorMsg = msg
        }
    }
}
