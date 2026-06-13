import SwiftUI
import UniformTypeIdentifiers

struct ShareComposerView: View {
    let initialText: String?
    let initialURL: URL?

    @State private var destination: HermesDestination = .coordinator
    @State private var prompt = ""
    @State private var contentTitle = ""
    @State private var contentText = ""
    @State private var contentURL = ""
    @State private var isSending = false
    @State private var status: String?
    @State private var lastResponse: HermesShareResponse?

    private let store = HermesConfigurationStore()

    init(initialText: String?, initialURL: URL?) {
        self.initialText = initialText
        self.initialURL = initialURL
        _contentText = State(initialValue: initialText ?? "")
        _contentURL = State(initialValue: initialURL?.absoluteString ?? "")
    }

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

                Section("content editor") {
                    TextField("title", text: $contentTitle)
                        .textInputAutocapitalization(.sentences)
                    TextField("url", text: $contentURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextEditor(text: $contentText)
                        .frame(minHeight: 120)

                    HStack {
                        Button("fill url sample") {
                            contentTitle = "hermes tailnet mvp"
                            contentURL = "https://example.com/hermes"
                            contentText = "check this tailnet-only endpoint and summarize what matters"
                        }
                        Button("fill text sample") {
                            contentTitle = "meeting note"
                            contentURL = ""
                            contentText = "hey mo, please distill this into a short task summary with next steps"
                        }
                    }
                    HStack {
                        Button("use shared payload") {
                            seedFromIncomingShare()
                        }
                        Button("clear") {
                            clearEditor()
                        }
                    }
                    .font(.footnote)
                }

                Section("context prompt") {
                    TextEditor(text: $prompt)
                        .frame(minHeight: 100)
                }

                Section("payload preview") {
                    Text(requestPreview)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Button(isSending ? "sending..." : "send to hermes") {
                    Task { await send() }
                }
                .disabled(isSending)

                Section("result") {
                    if let status {
                        Text(status)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("no request sent yet")
                            .foregroundStyle(.secondary)
                    }

                    if let lastResponse {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ok: \(lastResponse.ok)")
                            if let taskId = lastResponse.taskId { Text("task id: \(taskId)") }
                            if let messageId = lastResponse.messageId { Text("message id: \(messageId)") }
                            if let artifactPath = lastResponse.artifactPath { Text("artifact: \(artifactPath)") }
                            if let statusURL = lastResponse.statusURL { Text("status url: \(statusURL.absoluteString)") }
                        }
                        .font(.footnote)
                    }
                }
            }
            .navigationTitle("Send to Hermes")
        }
        .task {
            seedFromIncomingShare()
        }
    }

    private var requestPreview: String {
        let urlText = contentURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = contentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = contentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let payloadType = urlText.isEmpty ? "text" : "url"
        let preview = [
            "destination: \(destination.label)",
            "type: \(payloadType)",
            title.isEmpty ? nil : "title: \(title)",
            urlText.isEmpty ? nil : "url: \(urlText)",
            text.isEmpty ? nil : "text: \(text.prefix(120))"
        ].compactMap { $0 }.joined(separator: " · ")
        return preview.isEmpty ? "ready" : preview
    }

    private func seedFromIncomingShare() {
        if let initialText, contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            contentText = initialText
        }
        if let initialURL, contentURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            contentURL = initialURL.absoluteString
        }
        if contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           contentURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            contentText = ""
        }
    }

    private func clearEditor() {
        contentTitle = ""
        contentText = ""
        contentURL = ""
        status = nil
        lastResponse = nil
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

            let trimmedURL = contentURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let parsedURL = trimmedURL.isEmpty ? nil : URL(string: trimmedURL)
            let trimmedText = contentText.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedTitle = contentTitle.trimmingCharacters(in: .whitespacesAndNewlines)

            let payload = HermesSharePayload(
                schemaVersion: "1.0",
                destination: destination,
                agentId: destination.defaultAgentId,
                prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : prompt,
                source: HermesShareSource(
                    platform: "ios",
                    app: Bundle.main.bundleIdentifier,
                    shareExtensionVersion: HermesAppDefaults.shareExtensionVersion
                ),
                content: HermesSharedContent(
                    type: parsedURL == nil ? "text" : "url",
                    title: trimmedTitle.isEmpty ? nil : trimmedTitle,
                    url: parsedURL,
                    text: trimmedText.isEmpty ? nil : trimmedText,
                    files: []
                ),
                client: HermesClientMetadata(requestId: UUID(), createdAt: Date())
            )

            let client = HermesAPIClient(config: HermesConnectionConfig(endpointURL: endpoint)) {
                token
            }
            let response = try await client.send(payload)
            lastResponse = response
            if response.ok {
                let identifier = response.taskId ?? response.messageId ?? "ok"
                status = "gesendet ✓ \(identifier)"
            } else {
                status = "backend hat ok=false zurückgegeben"
            }
        } catch {
            status = "send failed: \(error.localizedDescription)"
        }
    }
}
