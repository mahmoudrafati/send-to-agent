import UIKit
import SwiftUI
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private var hostingController: UIHostingController<ShareComposerView>?
    private var didRequestSharedContent = false

    override func viewDidLoad() {
        super.viewDidLoad()
        embedComposer(initialText: nil, initialURL: nil)
        loadSharedContentIfNeeded()
    }

    private func embedComposer(initialText: String?, initialURL: URL?) {
        let composer = ShareComposerView(initialText: initialText, initialURL: initialURL)
        if let host = hostingController {
            host.rootView = composer
            return
        }

        let host = UIHostingController(rootView: composer)
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        hostingController = host
    }

    private func loadSharedContentIfNeeded() {
        guard !didRequestSharedContent,
              let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments,
              !attachments.isEmpty else {
            return
        }
        didRequestSharedContent = true

        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, _ in
                    let url = (item as? URL) ?? ((item as? NSURL) as URL?)
                    Task { @MainActor [weak self] in
                        self?.embedComposer(initialText: nil, initialURL: url)
                    }
                }
                return
            }
        }

        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) || provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                let typeIdentifier = provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) ? UTType.plainText.identifier : UTType.text.identifier
                provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [weak self] item, _ in
                    let text: String?
                    if let string = item as? String {
                        text = string
                    } else if let data = item as? Data {
                        text = String(data: data, encoding: .utf8)
                    } else {
                        text = nil
                    }
                    Task { @MainActor [weak self] in
                        self?.embedComposer(initialText: text, initialURL: nil)
                    }
                }
                return
            }
        }
    }
}
