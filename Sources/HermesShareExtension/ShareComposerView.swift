import SwiftUI
import UniformTypeIdentifiers

struct ShareComposerView: View {
    let initialText: String?
    let initialURL: URL?

    @State private var destination: HermesDestination = .coordinator
    @State private var prompt = ""
    @State private var isSending = false
    @State private var status: String?

    private let store = HermesConfigurationStore()

    var body: some View {
        NavigationStack {
            Form {
                Section("send to") {
                    Picker("destination", selection: $destination) {
                        ForEach(HermesDestination.allCases) { destination in
                            Text(destination.label).tag(destination)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("context prompt") {
                    TextEditor(text: $prompt)
                        .frame(minHeight: 100)
                }

                Section("shared content") {
                    if let initialURL {
                        Text(initialURL.absoluteString)
                    }
                    if let initialText {
                        Text(initialText)
                            .lineLimit(4)
                    }
                    if initialURL == nil, initialText == nil {
                        Text("No share payload yet.")
                            .foregroundStyle(.secondary)
                    }
                }

                Button(isSending ? "sending..." : "send to hermes") {
                    Task { await send() }
                }
                .disabled(isSending)

                if let status {
                    Text(status)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Send to Hermes")
        }
    }

    @MainActor
    private func send() async {
        isSending = true
        defer { isSending = false }

        do {
            guard let endpoint = store.loadEndpointURL() else {
                status = HermesConfigurationError.missingEndpoint.localizedDescription
                return
            }
            guard let token = try store.loadToken(), !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                status = HermesConfigurationError.missingToken.localizedDescription
                return
            }

            let payload = HermesSharePayload(
                schemaVersion: "1.0",
                destination: destination,
                agentId: destination.defaultAgentId,
                prompt: prompt.isEmpty ? nil : prompt,
                source: HermesShareSource(
                    platform: "ios",
                    app: Bundle.main.bundleIdentifier,
                    shareExtensionVersion: HermesAppDefaults.shareExtensionVersion
                ),
                content: HermesSharedContent(
                    type: initialURL != nil ? "url" : "text",
                    title: nil,
                    url: initialURL,
                    text: initialText,
                    files: []
                ),
                client: HermesClientMetadata(requestId: UUID(), createdAt: Date())
            )

            let client = HermesAPIClient(config: HermesConnectionConfig(endpointURL: endpoint)) {
                token
            }
            let response = try await client.send(payload)
            if response.ok {
                let identifier = response.taskId ?? response.messageId ?? "ok"
                status = "Gesendet ✓ \(identifier)"
            } else {
                status = "Backend hat ok=false zurückgegeben."
            }
        } catch {
            status = "Send failed: \(error.localizedDescription)"
        }
    }
}
