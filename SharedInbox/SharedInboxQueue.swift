//
//  SharedInboxQueue.swift
//  Finlogue / FinlogueShare
//
//  Hand-off between the share extension and the app. The extension runs in its
//  own process and cannot open the app's SwiftData store, so it appends the raw
//  message to a JSON file in the shared App Group container. The app drains that
//  file on activation and runs each entry through the normal import pipeline.
//
//  Deliberately dumb: no parsing, no model types. Whatever the extension writes
//  is re-parsed by the app, so improvements to the parser apply retroactively to
//  anything still sitting in the queue.
//

import Foundation

struct SharedInboxItem: Codable {
    var text: String
    var receivedAt: Date

    init(text: String, receivedAt: Date = .now) {
        self.text = text
        self.receivedAt = receivedAt
    }
}

enum SharedInboxQueue {
    /// Must match the App Group in both targets' entitlements.
    static let appGroupID = "group.co.hoomans.finlogue"

    private static let fileName = "shared-inbox.json"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    /// Appends a message. Called from the extension.
    static func enqueue(_ text: String) {
        guard let fileURL else { return }
        var items = load()
        items.append(SharedInboxItem(text: text))
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Returns everything queued and clears the file. Called from the app.
    static func drain() -> [SharedInboxItem] {
        let items = load()
        guard !items.isEmpty, let fileURL else { return items }
        try? FileManager.default.removeItem(at: fileURL)
        return items
    }

    static var isEmpty: Bool { load().isEmpty }

    private static func load() -> [SharedInboxItem] {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let items = try? JSONDecoder().decode([SharedInboxItem].self, from: data)
        else { return [] }
        return items
    }
}
