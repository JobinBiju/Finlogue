//
//  LogTransactionFromTextIntent.swift
//  Finlogue
//
//  Entry point for the Shortcuts "Message" personal automation. iOS exposes no
//  API for reading the Messages database, so the automation is the trigger and
//  this intent is the door into the app.
//

import AppIntents
import Foundation
import SwiftData

struct LogTransactionFromTextIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Transaction from Message"

    static var description = IntentDescription(
        """
        Reads a bank message and files the transaction in Finlogue. \
        Pair it with a Shortcuts automation that triggers on messages from your \
        bank. One-time passwords and promotional messages are ignored.
        """,
        categoryName: "Import"
    )

    /// Runs without bringing the app forward, so an automation set to "Run
    /// Immediately" is genuinely silent.
    static var openAppWhenRun = false

    @Parameter(
        title: "Message",
        description: "The bank message text.",
        inputOptions: String.IntentInputOptions(multiline: true)
    )
    var text: String

    @Parameter(
        title: "Sender",
        description: "The sender ID, e.g. HDFCBK-S. Controls how much the message is trusted.",
        default: ""
    )
    var sender: String

    /// Only `text` is interpolated: a summary with two inline parameters tends to
    /// collapse to the bare intent title in the automation editor, which hides
    /// the one field that must be filled in. `sender` is optional, so it sits in
    /// the expandable section instead.
    static var parameterSummary: some ParameterSummary {
        Summary("Log transaction from \(\.$text)") {
            \.$sender
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // An automation that never had the message variable inserted arrives
        // here with nothing. Saying so beats reporting a parse failure.
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .result(
                dialog: "No message text arrived. Check that the automation's Message field contains the Shortcut Input variable."
            )
        }

        let outcome = SMSImportService.ingest(
            text: text,
            sender: sender,
            store: TransactionStore.shared
        )
        return .result(dialog: IntentDialog(stringLiteral: dialog(for: outcome)))
    }

    /// Kept short: when an automation runs with "Notify When Run" on, this is
    /// what the banner shows.
    private func dialog(for outcome: SMSImportOutcome) -> String {
        switch outcome {
        case .autoConfirmed(let transaction):
            return "Added \(transaction.name)."
        case .queued(let pending):
            return "\(pending.name) is waiting in your Finlogue inbox."
        case .pairedIntoTransfer:
            return "Matched as a credit card payment."
        case .duplicate:
            return "Already recorded."
        case .rejected(let reason):
            // Echoing the opening words confirms the automation really did hand
            // over the message body, which is otherwise hard to verify.
            return "Ignored — \(reason.label.lowercased()): \"\(excerpt)\""
        }
    }

    private var excerpt: String {
        let flattened = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        return flattened.count > 40
            ? flattened.prefix(40).trimmingCharacters(in: .whitespaces) + "…"
            : flattened
    }
}

/// Makes the intent available as a Siri phrase in addition to Shortcuts.
struct FinlogueShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogTransactionFromTextIntent(),
            phrases: [
                "Log a transaction in \(.applicationName)",
                "Add a bank message to \(.applicationName)",
            ],
            shortTitle: "Log from Message",
            systemImageName: "text.badge.plus"
        )
    }
}
