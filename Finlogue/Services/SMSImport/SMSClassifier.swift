//
//  SMSClassifier.swift
//  Finlogue
//
//  Decides whether a bank SMS describes a settled transaction at all, and on
//  which instrument. Runs before any amount extraction: the point is to throw
//  messages away, not to understand them.
//

import Foundation

/// Why a message was not turned into a transaction.
enum SMSRejectReason: String, Error {
    case otp
    case promotional
    case informational
    case failedTransaction
    case noSettlementVerb
    case noAmount

    var label: String {
        switch self {
        case .otp: "One-time password"
        case .promotional: "Promotional message"
        case .informational: "Balance or reminder message"
        case .failedTransaction: "Failed or declined transaction"
        case .noSettlementVerb: "Not a completed transaction"
        case .noAmount: "No amount found"
        }
    }
}

enum SMSDirection: String {
    case debit
    case credit
}

/// How much a sender header can be trusted, derived from the Indian DLT
/// category suffix. `-S` (service-implicit) carries clean transactional alerts;
/// `-T` (service-explicit) mixes them with card OTPs; `-P` is promotional.
enum SMSTrustTier: Int, Comparable {
    case low = 0
    case medium = 1
    case high = 2

    static func < (lhs: SMSTrustTier, rhs: SMSTrustTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Sender headers arrive with a rotating two-character telecom-operator
    /// prefix that varies by circle and over time ("VM-HDFCBK-S", "JD-HDFCBK-S"),
    /// so only the trailing category letter is inspected.
    static func forSender(_ sender: String) -> SMSTrustTier {
        let upper = sender.uppercased()
        if upper.hasSuffix("-S") { return .high }
        if upper.hasSuffix("-T") { return .medium }
        if upper.hasSuffix("-P") { return .low }
        return .medium
    }
}

struct SMSClassification {
    var direction: SMSDirection
    var instrument: InstrumentKind?
    /// True for "payment received on your credit card", which pairs with a bank
    /// debit to form a single transfer rather than standalone income.
    var isCardPaymentReceipt: Bool
}

enum SMSClassifier {

    // MARK: Reject gates, in priority order

    /// Highest priority. A card OTP quotes an amount, a merchant *and* a card
    /// last-4 — "OTP is 481920 for txn of Rs 2,499.00 at AMAZON on card ending
    /// 5678" — so anything downstream would happily book a transaction that may
    /// never complete. This gate must run before everything else.
    private static let otpPatterns = [
        #"\botp\b"#,
        #"one[\s-]?time\s+password"#,
        #"verification\s+code"#,
        #"secure\s+code"#,
        #"\bcvv\b"#,
        #"(do\s*not|never|dont|don't)\s+share"#,
        #"for\s+txn\s+of"#,
        #"to\s+(authorise|authorize|authenticate)"#,
    ]

    private static let promotionalPatterns = [
        #"pre[\s-]?(approved|qualified)"#,
        #"apply\s+now"#,
        #"\boffer\b"#,
        #"limited\s+period"#,
        #"congratulations"#,
        #"\bt\s*&\s*c\b"#,
        #"click\s+(here|below|on)"#,
        #"unsubscribe"#,
        #"(bit\.ly|tinyurl|hdfcbk\.io|axisb\.co)"#,
        #"upgrade\s+your"#,
        #"\bemi\s+option"#,
    ]

    /// Statements and future-tense notices. These restate money that has already
    /// been (or has not yet been) booked; importing them double-counts the
    /// ledger.
    ///
    /// Balance phrases deliberately live in `balancePatterns` instead: they are
    /// only informational when they stand alone.
    private static let informationalPatterns = [
        #"statement\s+(is\s+)?(ready|generated)"#,
        #"min(imum)?\s+(amt\s+)?due"#,
        #"total\s+(amt\s+)?due"#,
        #"due\s+on\b"#,
        #"payment\s+reminder"#,
        #"e[\s-]?mandate"#,
        #"standing\s+instruction"#,
        #"will\s+be\s+(debited|deducted|charged|credited)"#,
        #"has\s+been\s+requested"#,
        #"is\s+due\b"#,
        #"credit\s+limit\s+(is|of)"#,
    ]

    /// A running balance is not a reject on its own. SBI, ICICI and HDFC all
    /// append one to genuine debit alerts — "Rs.500 debited from A/c XX1234 on
    /// 03-08-26 … Avl Bal Rs 2,300" — so treating the phrase as informational
    /// discards most real Indian bank SMS. These only decide the *reason* when
    /// the message turns out to carry no settlement verb, which is what a true
    /// balance enquiry looks like.
    private static let balancePatterns = [
        #"av(ai|b)?l\.?\s*bal"#,
        #"available\s+balance"#,
        #"a/c\s+balance"#,
        #"clos(ing)?\s*bal"#,
    ]

    private static let failurePatterns = [
        #"\bfailed\b"#,
        #"\bdeclined\b"#,
        #"unsuccessful"#,
        #"could\s+not\s+be\s+(processed|completed)"#,
        #"has\s+been\s+rejected"#,
    ]

    // MARK: Structural accept rules

    /// Past-tense settlement language. Paired with the account phrase below,
    /// this is what actually separates a real transaction from an OTP — far more
    /// durable than keyword blocklists, because it survives the bank rewording
    /// their template.
    private static let debitVerbs = [
        #"\bdebited\b"#,
        #"\bspent\b"#,
        #"\bwithdrawn\b"#,
        #"\bpaid\s+to\b"#,
        #"(amt\s+)?sent\b"#,
        #"\bdeducted\s+from\b"#,
        // HDFC's UPI-on-card alerts have no verb at all: "Txn Rs.53.00 On HDFC
        // Bank Card 9312". Safe to treat as a settled debit only because the OTP
        // gate above already claims "for txn of", and the failure gate claims
        // declined ones — both run first.
        #"^\s*txn\b"#,
        #"\btxn\s+(of\s+)?(rs|inr|₹)"#,
    ]

    private static let creditVerbs = [
        #"\bcredited\b"#,
        #"\breceived\b"#,
        #"\brefund(ed)?\b"#,
        #"\breversed\b"#,
        #"\bdeposited\b"#,
    ]

    /// A settled transaction always names the instrument the money moved on.
    private static let accountPhrases = [
        #"\ba/?c\b"#,
        #"\bacct\b"#,
        #"\baccount\b"#,
        #"\bcard\b"#,
    ]

    private static let cardPaymentPatterns = [
        #"payment\s+(of\s+)?(rs|inr|₹)?.{0,20}received"#,
        #"payment\s+received"#,
        #"credited\s+towards\s+your\s+card"#,
        #"thank\s+you\s+for\s+(your\s+)?payment"#,
    ]

    // MARK: Entry point

    static func classify(_ text: String) -> Result<SMSClassification, SMSRejectReason> {
        let haystack = text.lowercased()

        if matchesAny(otpPatterns, in: haystack) { return .failure(.otp) }
        if matchesAny(promotionalPatterns, in: haystack) { return .failure(.promotional) }
        if matchesAny(informationalPatterns, in: haystack) { return .failure(.informational) }
        if matchesAny(failurePatterns, in: haystack) { return .failure(.failedTransaction) }

        let isDebit = matchesAny(debitVerbs, in: haystack)
        let isCredit = matchesAny(creditVerbs, in: haystack)
        guard isDebit || isCredit else {
            // Nothing settled. A quoted balance means this was a balance
            // enquiry, which is worth saying plainly in the rejection.
            return .failure(
                matchesAny(balancePatterns, in: haystack) ? .informational : .noSettlementVerb
            )
        }
        guard matchesAny(accountPhrases, in: haystack) else {
            return .failure(.noSettlementVerb)
        }

        // When both appear ("debited ... credited to beneficiary") the debit is
        // the side that belongs to the user's own account.
        let direction: SMSDirection = isDebit ? .debit : .credit

        return .success(
            SMSClassification(
                direction: direction,
                instrument: instrument(in: haystack),
                isCardPaymentReceipt: matchesAny(cardPaymentPatterns, in: haystack)
            )
        )
    }

    /// A debit-card swipe hits the *bank account*, not a separate card account —
    /// only the quoted last-4 differs. Checked before the bare "account" phrase
    /// so "spent via Debit Card XX9012 from a/c" resolves as the card.
    static func instrument(in lowercasedText: String) -> InstrumentKind? {
        if matchesAny([#"credit\s*card"#, #"\bcc\b"#], in: lowercasedText) {
            return .creditCard
        }
        if matchesAny([#"debit\s*card"#], in: lowercasedText) {
            return .debitCard
        }
        if matchesAny([#"\ba/?c\b"#, #"\bacct\b"#, #"\baccount\b"#], in: lowercasedText) {
            return .accountNumber
        }
        // A bare "card ending 1234" is genuinely ambiguous between the user's
        // debit and credit cards; leaving it nil sends the row to review, where
        // the user's answer is remembered as an AccountIdentifier.
        return nil
    }

    private static func matchesAny(_ patterns: [String], in haystack: String) -> Bool {
        patterns.contains { RegexKit.matches($0, in: haystack) }
    }
}
