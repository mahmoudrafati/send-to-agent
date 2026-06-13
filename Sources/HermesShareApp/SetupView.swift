import SwiftUI

struct SetupView: View {
    @State private var baseURL = ""
    @State private var token = ""
    @State private var status: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Hermes endpoint") {
                    TextField("https://your-hermes.example.com", text: $baseURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("api token", text: $token)
                }

                Section("security") {
                    Text("token should be saved in keychain, never userdefaults")
                    Text("this scaffold leaves keychain implementation as the next concrete step")
                }

                Button("save config") {
                    // TODO: validate url, save endpoint in app group defaults, token in keychain
                    status = "config validation placeholder"
                }

                if let status {
                    Text(status)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Hermes Share")
        }
    }
}

#Preview {
    SetupView()
}
