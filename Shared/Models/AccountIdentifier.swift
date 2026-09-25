//
//  AccountIdentifier.swift
//  Finlogue
//

import Foundation
import SwiftData

/// Which instrument a set of last-4 digits belongs to. A bank SMS quotes the
/// *card* number for card swipes and the *account* number for UPI/NEFT, so the
/// same underlying account is referred to by more than one last-4.
enum InstrumentKind: String, Codable, CaseIterable, Identifiable {
    case accountNumber
    case debitCard
    case creditCard

    var id: String { rawValue }

    var label: String {
        switch self {
        case .accountNumber: "Account Number"
        case .debitCard: "Debit Card"
        case .creditCard: "Credit Card"
        }
    }
}

/// Maps the last 4 digits quoted in a bank SMS to one of the user's accounts.
///
/// Deliberately one-to-many: an HDFC savings account owns both its account
/// number and its debit card number, while the HDFC credit card owns a third.
/// Resolution matches on `(last4, kind)` together — last4 alone is ambiguous
/// because a bank account and a card can coincidentally share four digits.
@Model
final class AccountIdentifier {
    @Attribute(.unique) var id: UUID
    /// Exactly 4 digits, no masking characters.
    var last4: String
    var kindRaw: String
    var account: Account?
    /// True when the mapping was created by the user answering "which account
    /// is XX9012?" in the review queue rather than typed during account setup.
    var isLearned: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        last4: String,
        kind: InstrumentKind,
        account: Account? = nil,
        isLearned: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.last4 = last4
        self.kindRaw = kind.rawValue
        self.account = account
        self.isLearned = isLearned
        self.createdAt = createdAt
    }

    var kind: InstrumentKind {
        get { InstrumentKind(rawValue: kindRaw) ?? .accountNumber }
        set { kindRaw = newValue.rawValue }
    }
}
