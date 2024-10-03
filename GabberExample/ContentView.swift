import SwiftUI

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
        .alert(item: Binding<AlertItem?>(
            get: { viewModel.error.map { AlertItem(message: $0) } },
            set: { _ in viewModel.error = nil }
        )) { alertItem in
            Alert(title: Text("Error"), message: Text(alertItem.message))
        }
    }
    
    private var connectionView: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Fetching connection details...")
            } else {
                Button("Connect") {
                    print("Connect button pressed")
                    viewModel.fetchConnectionDetails()
                }
                .padding()
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
                    Text(message.text)
                }
            }
            
            HStack {
                TextField("Type a message", text: $viewModel.inputMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Send") {
                    print("Send button pressed")
                    viewModel.sendMessage()
                }
            }
            .padding()
            
            HStack {
                Button(viewModel.microphoneEnabled ? "Mute" : "Unmute") {
                    print("\(viewModel.microphoneEnabled ? "Mute" : "Unmute") button pressed")
                    viewModel.toggleMicrophone()
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
            
            Text("Agent state: \(viewModel.agentState.description)")
        }
    }
}

struct AlertItem: Identifiable {
    let id = UUID()
    let message: String
}
