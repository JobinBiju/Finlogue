//
//  ShareViewController.swift
//  FinlogueShare
//
//  Receives a bank message shared out of Messages (hold the bubble → Select →
//  share) and hands it to the app through the shared App Group queue.
//
//  Intentionally minimal: no parsing happens here. The extension has a short
//  lifetime and no access to the store, and re-parsing in the app means a queued
//  message benefits from any later parser fix.
//

import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        extractSharedText { [weak self] text in
            guard let self else { return }
            if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                SharedInboxQueue.enqueue(text)
                present(message: "Saved to Finlogue's review inbox.")
            } else {
                present(message: "No text found in that message.")
            }
        }
    }

    /// Messages shares a bubble as plain text; some senders arrive as a URL
    /// attachment instead, so both are accepted.
    private func extractSharedText(completion: @escaping (String?) -> Void) {
        let attachments = (extensionContext?.inputItems as? [NSExtensionItem])?
            .compactMap(\.attachments)
            .flatMap { $0 } ?? []

        let textType = UTType.plainText.identifier
        let urlType = UTType.url.identifier

        guard let provider = attachments.first(where: {
            $0.hasItemConformingToTypeIdentifier(textType)
                || $0.hasItemConformingToTypeIdentifier(urlType)
        }) else {
            completion(nil)
            return
        }

        let type = provider.hasItemConformingToTypeIdentifier(textType) ? textType : urlType
        provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
            let text: String? = switch item {
            case let value as String: value
            case let value as URL: value.absoluteString
            case let value as NSAttributedString: value.string
            case let value as Data: String(data: value, encoding: .utf8)
            default: nil
            }
            DispatchQueue.main.async { completion(text) }
        }
    }

    private func present(message: String) {
        let alert = UIAlertController(
            title: "Finlogue", message: message, preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Done", style: .default) { [weak self] _ in
            self?.extensionContext?.completeRequest(returningItems: nil)
        })
        present(alert, animated: true)
    }
}
