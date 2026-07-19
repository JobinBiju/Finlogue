//
//  RecurringSplit.swift
//  Finlogue
//
//  A person's share template on a recurring rule. When the rule posts an
//  occurrence, these are copied onto the new transaction as TransactionSplits —
//  so a shared subscription splits the same way every period. Templates
//  themselves are not debts; only the posted TransactionSplits count in ledgers.
//

import Foundation
import SwiftData

@Model
final class RecurringSplit {
    @Attribute(.unique) var id: UUID
    var rule: RecurringRule?
    var person: Person?
    var shareAmount: Double

    init(
        id: UUID = UUID(),
        rule: RecurringRule? = nil,
        person: Person? = nil,
        shareAmount: Double
    ) {
        self.id = id
        self.rule = rule
        self.person = person
        self.shareAmount = shareAmount
    }
}
