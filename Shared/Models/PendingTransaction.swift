//
//  PendingTransaction.swift
//  Finlogue
//

import Foundation
import SwiftData

/// A transaction parsed out of a bank SMS, waiting for the user to confirm it.
///
/// Nothing parsed from an SMS is ever written straight into the ledger unless it
/// clears a high trust bar (see `SMSImportService`); everything else lands here.
/// A wrong auto-import costs far more user trust than an extra tap.
///
/// Account/category links are stored as raw IDs rather than SwiftData
/// relationships on purpose: these rows are short-lived and adding two more
/// `Account` relationships would need explicit inverses declared on `Account`
/// to avoid the dangling-row crash documented there.
@Model
final class PendingTransaction {
    @Attribute(.unique) var id: UUID

    // MARK: Source
    var rawText: String
    /// Sender header as reported by Shortcuts, e.g. "VM-HDFCBK-S".
    var senderID: String

    // MARK: Parsed
    var amount: Double
    /// Suggested `TransactionType` raw value.
    var typeRaw: String
    /// Display name, editable in the review inbox before booking.
    var name: String
    /// Merchant string as it appeared in the message. Kept separate from `name`
    /// because a learned `MerchantRule` has to match future *raw* messages — if
    /// the user renames "Ing*REDBUS INDIA PVT L" to "Redbus", a rule keyed on
    /// "redbus" alone would stop matching the bank's own wording.
    var parsedMerchant: String?
    var last4: String?
    var instrumentRaw: String
    var refID: String?
    var date: Date
    /// 0...1. Below `SMSImportService.autoConfirmConfidence` this always needs
    /// a human look even on a trusted sender.
    var confidence: Double

    // MARK: Resolution
    var resolvedAccountID: UUID?
    /// Destination account for a paired card payment (a transfer).
    var resolvedToAccountID: UUID?
    var suggestedCategoryID: UUID?
    /// True when the last-4 in the message matched no known identifier, so the
    /// review screen must ask the user which account it belongs to.
    var needsAccountChoice: Bool

    var createdAt: Date

    init(
        id: UUID = UUID(),
        rawText: String,
        senderID: String,
        amount: Double,
        type: TransactionType,
        name: String,
        parsedMerchant: String? = nil,
        last4: String? = nil,
        instrument: InstrumentKind? = nil,
        refID: String? = nil,
        date: Date = .now,
        confidence: Double = 0,
        resolvedAccountID: UUID? = nil,
        resolvedToAccountID: UUID? = nil,
        suggestedCategoryID: UUID? = nil,
        needsAccountChoice: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.rawText = rawText
        self.senderID = senderID
        self.amount = amount
        self.typeRaw = type.rawValue
        self.name = name
        self.parsedMerchant = parsedMerchant
        self.last4 = last4
        self.instrumentRaw = instrument?.rawValue ?? ""
        self.refID = refID
        self.date = date
        self.confidence = confidence
        self.resolvedAccountID = resolvedAccountID
        self.resolvedToAccountID = resolvedToAccountID
        self.suggestedCategoryID = suggestedCategoryID
        self.needsAccountChoice = needsAccountChoice
        self.createdAt = createdAt
    }

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    var instrument: InstrumentKind? {
        get { InstrumentKind(rawValue: instrumentRaw) }
        set { instrumentRaw = newValue?.rawValue ?? "" }
    }

    /// Masked form for display, e.g. "•• 5678".
    var maskedLast4: String? {
        last4.map { "•• \($0)" }
    }
}
