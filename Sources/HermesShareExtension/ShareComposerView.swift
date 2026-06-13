import SwiftUI
import UniformTypeIdentifiers

struct ShareComposerView: View {
    let initialText: String?
    let initialURL: URL?

    @State private var destination: HermesDestination = .coordinator
    @State private var prompt = ""
    @State private var isSending = false
    @State private var status: String?

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

    private func send() async {
        isSending = true
        defer { isSending = false }

        // TODO: load config from app group + token from keychain
        // TODO: build HermesAPIClient and POST payload
        let payload = HermesSharePayload(
            schemaVersion: "1.0",
            destination: destination,
            agentId: destination == .coordinator ? "default" : "ingestion",
            prompt: prompt.isEmpty ? nil : prompt,
            source: HermesShareSource(platform: "ios", app: nil, shareExtensionVersion: "0.1.0"),
            content: HermesSharedContent(
                type: initialURL != nil ? "url" : "text",
                title: nil,
                url: initialURL,
                text: initialText,
                files: []
            ),
            client: HermesClientMetadata(requestId: UUID(), createdAt: Date())
        )

        status = "payload ready: \(payload.destination.rawValue)"
    }
}
