import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = GabberViewModel()
    
    var body: some View {
        VStack {
            Text("Connection State: \(viewModel.connectionState)")
                .padding();
            
            Text("Agent State: \(viewModel.agentState)");
            
            if !viewModel.errorMsg.isEmpty {
                Text("Error: \(viewModel.errorMsg)").foregroundColor(.red)
                    .padding()
            }

            Button("Start Session") {
                viewModel.startSession()
            }
            .padding()
            
            // You can expand this view with additional UI elements as needed
        }
        .padding()
    }
}
