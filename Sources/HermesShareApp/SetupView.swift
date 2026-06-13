import SwiftUI

struct SetupView: View {
    @State private var endpointText = ""
    @State private var token = ""
    @State private var status: String?

    private let store = HermesConfigurationStore()

    var body: some View {
        NavigationStack {
            Form {
                Section("Tailscale endpoint") {
                    TextField("https://your-tailnet-host.example.com", text: $endpointText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Text("Endpoint bleibt private/Tailscale-only. Bearer Token liegt im App-Group-Storage, Endpoint in Shared Defaults.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("API token") {
                    SecureField("Bearer token", text: $token)
                    Text("Leer lassen = vorhandenen Token behalten.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("status") {
                    Text(store.currentConfiguration().hasStoredToken ? "Token ist im App-Group-Storage gespeichert." : "Noch kein Token gespeichert.")
                        .foregroundStyle(.secondary)
                }

                Button("Save config") {
                    saveConfiguration()
                }

                if let status {
                    Text(status)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Hermes Share")
            .task {
                loadConfiguration()
            }
        }
    }

    @MainActor
    private func loadConfiguration() {
        if let endpoint = store.loadEndpointURL() {
            endpointText = endpoint.absoluteString
        }
        status = store.hasStoredToken() ? "Config geladen." : "Endpoint setzen und Token speichern."
    }

    @MainActor
    private func saveConfiguration() {
        do {
            let validatedEndpoint = try store.validateEndpoint(endpointText)
            store.saveEndpointURL(validatedEndpoint)

            let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedToken.isEmpty {
                try store.saveToken(trimmedToken)
                token = ""
                status = "Endpoint + Token gespeichert."
            } else if store.hasStoredToken() {
                status = "Endpoint gespeichert. Vorhandener Token bleibt im App-Group-Storage."
            } else {
                status = "Endpoint gespeichert, aber noch kein Token vorhanden."
            }
        } catch {
            status = error.localizedDescription
        }
    }
}

#Preview {
    SetupView()
}
