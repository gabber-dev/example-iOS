import SwiftUI
import Gabber

struct ContentView: View {
    @StateObject private var viewModel = GabberViewModel()
    
    var body: some View {
        VStack {
            switch viewModel.connectionState {
            case .notConnected:
                connectionView
            case .connecting, .waitingForAgent:
                connectionView
            case .connected:
                chatView
            }
        }
    }
    
    private var connectionView: some View {
        VStack {
            TextField("Enter text here", text: $viewModel.prompt)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle()) // Styling for the text field
            Text("Select Voice:")
            ScrollView(.vertical) {
                VStack {
                    ForEach(viewModel.voices, id: \.id) { voice in
                        VoiceRow(voice: voice, isSelected: viewModel.selectedVoiceId == voice.id) {
                            viewModel.selectedVoiceId = voice.id // Update selected voice
                            print("Selected voice: \(voice.name)")
                        }
                    }
                }
            }
            Button("Connect") {
                Task {
                    do {
                        try await viewModel.connect()
                    } catch {
                        print("Connection failed \(error)")
                    }
                }
            }.frame(height: 100)
        }.onAppear {
            Task {
                do {
                    try await viewModel.fetchVoices()
                } catch {
                    AlertItem(message: "Error fetching voices")
                }
            }
        }
    }
    
    private var chatView: some View {
        VStack {
            List(viewModel.messages, id: \.id) { message in
                HStack {
                    if message.agent {
                        Text("Agent: ")
                            .fontWeight(.bold)
                    } else {
                        Text("You: ")
                            .fontWeight(.bold)
                    }
                    Text(message.text ?? "")
                }
            }
            
            HStack {
                TextField("Type a message", text: $viewModel.inputMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Send") {
                    print("Send button pressed")
                    Task {
                        do {
                            try await viewModel.sendMessage()
                        } catch {
                            print("Error sending message")
                        }
                    }
                    
                }
            }
            .padding()
            
            HStack {
                Button(viewModel.microphoneEnabled ? "Mute" : "Unmute") {
                    print("\(viewModel.microphoneEnabled ? "Mute" : "Unmute") button pressed")
                    Task {
                        do {
                            try await viewModel.toggleMicrophone()
                        } catch {
                            print("Error toggling microphone")
                        }
                    }
                }
                
                Button("Disconnect") {
                    print("Disconnect button pressed")
                    viewModel.disconnect()
                }
            }
            .padding()
            
            if let remainingSeconds = viewModel.remainingSeconds {
                Text("Remaining time: \(Int(remainingSeconds))s")
            }
            
            Text("Agent state: \(viewModel.agentState)")
        }
    }
}

struct VoiceRow: View {
    let voice: Voice
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Text(voice.name)
            .padding()
            .background(isSelected ? Color.green : Color.blue) // Highlight selected voice
            .foregroundColor(.white)
            .cornerRadius(10)
            .onTapGesture {
                onSelect() // Call the selection closure when tapped
            }
    }
}

struct AlertItem: Identifiable {
    let id = UUID()
    let message: String
}
