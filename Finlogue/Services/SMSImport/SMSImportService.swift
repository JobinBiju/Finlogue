//
//  SMSImportService.swift
//  Finlogue
//
//  Maps a `ParsedSMS` onto the user's accounts, drops duplicates, merges the
//  two-message card-payment pair into a single transfer, and either queues the
//  result for review or books it.
//

import Foundation
import SwiftData

enum SMSImportOutcome {
    case rejected(SMSRejectReason)
    /// Same transaction already queued or already in the ledger.
    case duplicate
    case queued(PendingTransaction)
    /// Merged into an already-queued row to form a transfer.
    case pairedIntoTransfer(PendingTransaction)
    case autoConfirmed(Transaction)

    var userFacingSummary: String {
        switch self {
        case .rejected(let reason): "Ignored — \(reason.label.lowercased())"
        case .duplicate: "Already recorded"
        case .queued: "Added to review inbox"
        case .pairedIntoTransfer: "Matched as a card payment"
        case .autoConfirmed: "Added"
        }
    }
}

@MainActor
enum SMSImportService {

    /// Below this, a row always needs a human look even on a trusted sender.
    static let autoConfirmConfidence = 0.9

    /// Window for treating two messages as describing the same event. Banks
    /// routinely send a card alert and a UPI/merchant alert for one swipe.
    private static let duplicateWindow: TimeInterval = 30 * 60

    /// Card payments generate a bank debit and a card credit, usually seconds
    /// apart but occasionally spanning a settlement delay.
    private static let pairingWindow: TimeInterval = 6 * 60 * 60

    // MARK: Entry point

    static func ingest(
        text: String,
        sender: String,
        store: TransactionStore,
        now: Date = .now
    ) -> SMSImportOutcome {
        let parsed: ParsedSMS
        switch SMSTransactionParser.parse(text, sender: sender, now: now) {
        case .success(let value): parsed = value
        case .failure(let reason): return .rejected(reason)
        }

        let context = store.context

        if isDuplicate(parsed, context: context) { return .duplicate }

        // Pairing must run before insertion: the card side of a payment is not a
        // standalone income row, it completes a transfer already in the queue.
        if parsed.isCardPaymentReceipt || looksLikeCardPaymentDebit(parsed),
           let paired = pairCardPayment(parsed, context: context, store: store) {
            return .pairedIntoTransfer(paired)
        }

        let account = resolveAccount(parsed, context: context)
        let type: TransactionType = parsed.direction == .debit ? .expense : .income
        let merchantMatch = merchantRule(for: parsed, context: context)
        let name = merchantMatch?.displayName
            ?? parsed.merchant
            ?? defaultName(for: parsed)

        let pending = PendingTransaction(
            rawText: parsed.rawText,
            senderID: parsed.senderID,
            amount: parsed.amount,
            type: type,
            name: name,
            parsedMerchant: parsed.merchant,
            last4: parsed.last4,
            instrument: parsed.instrument,
            refID: parsed.refID,
            date: parsed.date,
            confidence: parsed.confidence,
            resolvedAccountID: account?.id,
            suggestedCategoryID: merchantMatch?.categoryID,
            needsAccountChoice: account == nil
        )

        // Inserted first either way: `confirm` promotes the queued row and
        // deletes it, so it must be a managed object before that runs.
        context.insert(pending)

        if shouldAutoConfirm(parsed, resolvedAccount: account),
           let transaction = confirm(pending, store: store) {
            return .autoConfirmed(transaction)
        }

        store.persist()
        return .queued(pending)
    }

    // MARK: Confirmation

    /// Promotes a queued row into the ledger and removes it from the inbox.
    /// Routed through `TransactionStore` so balance recomputation and watch sync
    /// happen exactly as they do for a hand-entered transaction.
    @discardableResult
    static func confirm(
        _ pending: PendingTransaction,
        store: TransactionStore,
        overrideAccount: Account? = nil,
        overrideCategory: Category? = nil
    ) -> Transaction? {
        let context = store.context
        let sourceAccount = overrideAccount
            ?? Self.account(id: pending.resolvedAccountID, context: context)
        let destinationAccount = Self.account(
            id: pending.resolvedToAccountID, context: context
        )
        let category = overrideCategory
            ?? Self.category(id: pending.suggestedCategoryID, context: context)

        store.addTransaction(
            type: pending.type,
            name: pending.name,
            amount: pending.amount,
            date: pending.date,
            note: noteForImport(pending),
            account: sourceAccount,
            toAccount: destinationAccount,
            category: pending.type == .transfer ? nil : category
        )

        // Remember the user's corrections so the same merchant needs reviewing
        // only once.
        learn(
            from: pending, account: sourceAccount,
            category: category, context: context
        )

        let inserted = mostRecentTransaction(matching: pending, context: context)
        context.delete(pending)
        store.persist()
        return inserted
    }

    static func discard(_ pending: PendingTransaction, store: TransactionStore) {
        store.context.delete(pending)
        store.persist()
    }

    // MARK: Resolution

    /// Instrument keyword narrows the kind, last-4 picks the row. Both signals
    /// together, because a last-4 alone is ambiguous across a bank account and a
    /// card that happen to share four digits.
    static func resolveAccount(_ parsed: ParsedSMS, context: ModelContext) -> Account? {
        guard let last4 = parsed.last4 else { return nil }
        let identifiers = (try? context.fetch(FetchDescriptor<AccountIdentifier>())) ?? []
        let candidates = identifiers.filter { $0.last4 == last4 }
        guard !candidates.isEmpty else { return nil }

        if let instrument = parsed.instrument,
           let exact = candidates.first(where: { $0.kind == instrument }) {
            return exact.account
        }
        // Unambiguous even without an instrument keyword: only one account owns
        // these digits.
        if candidates.count == 1 { return candidates[0].account }

        // A debit card and its own account are the same money, so several
        // identifiers pointing at one account is still a clean resolution.
        let accounts = Set(candidates.compactMap(\.account?.id))
        return accounts.count == 1 ? candidates[0].account : nil
    }

    /// Records `last4 → account` after the user answers "which account is this?"
    /// so the mapping resolves automatically from then on.
    static func learnIdentifier(
        last4: String,
        kind: InstrumentKind,
        account: Account,
        store: TransactionStore
    ) {
        let context = store.context
        let existing = (try? context.fetch(FetchDescriptor<AccountIdentifier>())) ?? []
        guard !existing.contains(where: {
            $0.last4 == last4 && $0.kind == kind && $0.account?.id == account.id
        }) else { return }

        context.insert(
            AccountIdentifier(last4: last4, kind: kind, account: account, isLearned: true)
        )
        store.persist()
    }

    // MARK: Duplicates

    /// Keyed on amount, instrument last-4 and a time window, plus the bank
    /// reference when both messages carry one. Two alerts for a single swipe
    /// share all of these; a card payment's two legs do not, because their
    /// last-4s differ — those need merging, which is a separate pass.
    private static func isDuplicate(_ parsed: ParsedSMS, context: ModelContext) -> Bool {
        let lower = parsed.date.addingTimeInterval(-duplicateWindow)
        let upper = parsed.date.addingTimeInterval(duplicateWindow)

        let queued = (try? context.fetch(FetchDescriptor<PendingTransaction>())) ?? []
        let pendingHit = queued.contains { candidate in
            candidate.amount == parsed.amount
                && candidate.date >= lower && candidate.date <= upper
                && matchesIdentity(candidate.last4, parsed.last4, candidate.refID, parsed.refID)
        }
        if pendingHit { return true }

        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.date >= lower && $0.date <= upper }
        )
        descriptor.fetchLimit = 200
        let booked = (try? context.fetch(descriptor)) ?? []
        return booked.contains { candidate in
            candidate.amount == parsed.amount
                && parsed.refID != nil
                && candidate.note?.contains(parsed.refID ?? "\u{0}") == true
        }
    }

    /// A shared bank reference is conclusive. Otherwise fall back to the last-4,
    /// treating a missing value on either side as "can't tell them apart".
    private static func matchesIdentity(
        _ lhsLast4: String?, _ rhsLast4: String?,
        _ lhsRef: String?, _ rhsRef: String?
    ) -> Bool {
        if let lhsRef, let rhsRef { return lhsRef == rhsRef }
        guard let lhsLast4, let rhsLast4 else { return true }
        return lhsLast4 == rhsLast4
    }

    // MARK: Card-payment pairing

    /// The bank leg of a card payment: money leaving the account towards a card.
    private static func looksLikeCardPaymentDebit(_ parsed: ParsedSMS) -> Bool {
        guard parsed.direction == .debit else { return false }
        let haystack = parsed.rawText.lowercased()
        return RegexKit.matches(#"(credit\s*card|\bcc\b|card\s+payment)"#, in: haystack)
            && parsed.instrument == .accountNumber
    }

    /// Merges the two legs into one transfer. Without this the pair books as an
    /// expense *and* an income — double-counted, and both wrong.
    private static func pairCardPayment(
        _ parsed: ParsedSMS,
        context: ModelContext,
        store: TransactionStore
    ) -> PendingTransaction? {
        let queued = (try? context.fetch(FetchDescriptor<PendingTransaction>())) ?? []
        let account = resolveAccount(parsed, context: context)

        // The counterpart is the same amount, opposite direction, inside the
        // settlement window, on a *different* instrument.
        guard let counterpart = queued.first(where: { candidate in
            candidate.amount == parsed.amount
                && abs(candidate.date.timeIntervalSince(parsed.date)) <= pairingWindow
                && candidate.type != .transfer
                && candidate.last4 != parsed.last4
                && (candidate.type == .expense) != (parsed.direction == .debit)
        }) else { return nil }

        let bankSide = parsed.direction == .debit
            ? account?.id
            : counterpart.resolvedAccountID
        let cardSide = parsed.direction == .debit
            ? counterpart.resolvedAccountID
            : account?.id

        counterpart.type = .transfer
        counterpart.name = "Credit Card Payment"
        counterpart.resolvedAccountID = bankSide
        counterpart.resolvedToAccountID = cardSide
        counterpart.suggestedCategoryID = nil
        counterpart.needsAccountChoice = bankSide == nil || cardSide == nil
        counterpart.rawText += "\n\n" + parsed.rawText
        store.persist()
        return counterpart
    }

    // MARK: Trust

    /// `HDFCBK-T` carries card OTPs alongside real transactions, so a
    /// medium-trust sender never auto-confirms regardless of confidence: one OTP
    /// booked as an expense costs more trust than ten manual taps.
    private static func shouldAutoConfirm(
        _ parsed: ParsedSMS,
        resolvedAccount: Account?
    ) -> Bool {
        guard AppSettings.smsAutoConfirmEnabled else { return false }
        guard resolvedAccount != nil else { return false }
        guard parsed.confidence >= autoConfirmConfidence else { return false }
        guard parsed.amountAppearsInRawText else { return false }
        return SMSTrustTier.forSender(parsed.senderID) == .high
    }

    // MARK: Learning

    private static func merchantRule(
        for parsed: ParsedSMS,
        context: ModelContext
    ) -> MerchantRule? {
        guard let merchant = parsed.merchant?.lowercased() else { return nil }
        let rules = (try? context.fetch(FetchDescriptor<MerchantRule>())) ?? []
        return rules
            .filter { merchant.contains($0.pattern) }
            .max(by: { $0.hitCount < $1.hitCount })
    }

    private static func learn(
        from pending: PendingTransaction,
        account: Account?,
        category: Category?,
        context: ModelContext
    ) {
        if let last4 = pending.last4, let account, let kind = pending.instrument {
            let existing = (try? context.fetch(FetchDescriptor<AccountIdentifier>())) ?? []
            if !existing.contains(where: {
                $0.last4 == last4 && $0.kind == kind && $0.account?.id == account.id
            }) {
                context.insert(
                    AccountIdentifier(
                        last4: last4, kind: kind, account: account, isLearned: true
                    )
                )
            }
        }

        guard pending.type != .transfer, let category else { return }
        // Keyed on what the bank writes, not on the name the user chose to see,
        // so the rule still fires on the next message from this merchant.
        let pattern = (pending.parsedMerchant ?? pending.name).lowercased()
        guard pattern.count >= 3 else { return }
        let rules = (try? context.fetch(FetchDescriptor<MerchantRule>())) ?? []
        if let existing = rules.first(where: { $0.pattern == pattern }) {
            existing.categoryID = category.id
            existing.displayName = pending.name
            existing.hitCount += 1
            existing.updatedAt = .now
        } else {
            context.insert(
                MerchantRule(
                    pattern: pattern,
                    displayName: pending.name,
                    categoryID: category.id,
                    hitCount: 1
                )
            )
        }
    }

    // MARK: Lookups

    private static func defaultName(for parsed: ParsedSMS) -> String {
        switch parsed.direction {
        case .debit: "Card Spend"
        case .credit: "Credit Received"
        }
    }

    /// The bank reference is written into the note so a later re-import of the
    /// same message can recognise it as already booked.
    private static func noteForImport(_ pending: PendingTransaction) -> String {
        var parts = ["Imported from SMS"]
        if let refID = pending.refID { parts.append("Ref \(refID)") }
        if let masked = pending.maskedLast4 { parts.append(masked) }
        return parts.joined(separator: " · ")
    }

    private static func account(id: UUID?, context: ModelContext) -> Account? {
        guard let id else { return nil }
        var descriptor = FetchDescriptor<Account>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private static func category(id: UUID?, context: ModelContext) -> Category? {
        guard let id else { return nil }
        var descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// `TransactionStore.addTransaction` does not hand back the row it created,
    /// so the freshly inserted match is read back for the caller's result.
    private static func mostRecentTransaction(
        matching pending: PendingTransaction,
        context: ModelContext
    ) -> Transaction? {
        var descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 10
        let recent = (try? context.fetch(descriptor)) ?? []
        return recent.first {
            $0.amount == pending.amount && $0.name == pending.name
        }
    }
}
