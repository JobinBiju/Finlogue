//
//  SMSTransactionParser.swift
//  Finlogue
//
//  Turns a classified bank SMS into a `ParsedSMS`. Extraction only — deciding
//  whether the message is a transaction is `SMSClassifier`'s job, and mapping it
//  onto the user's accounts is `SMSImportService`'s.
//

import Foundation

/// Everything extractable from the message text, before it is matched against
/// the user's accounts. `instrument` and `last4` stay separate from any resolved
/// account so extraction can be tested without a data store.
struct ParsedSMS {
    var amount: Double
    /// The amount exactly as written ("1,234.56"). Kept so a parse can be
    /// verified to appear verbatim in the source text — the guard that catches
    /// an on-device model inventing a figure.
    var amountLiteral: String
    var direction: SMSDirection
    var instrument: InstrumentKind?
    var last4: String?
    var merchant: String?
    var refID: String?
    var date: Date
    var isCardPaymentReceipt: Bool
    var rawText: String
    var senderID: String
    var confidence: Double

    /// Sanity check against hallucinated or mis-grouped figures: the digits the
    /// parser claims to have read must actually be present in the message.
    var amountAppearsInRawText: Bool {
        rawText.replacingOccurrences(of: " ", with: "")
            .contains(amountLiteral.replacingOccurrences(of: " ", with: ""))
    }
}

private extension String {
    var capitalizedFirstLetter: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

enum SMSTransactionParser {

    private static let amountPatterns = [
        #"(?:rs\.?|inr|₹)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)"#,
        // Trailing-currency form: "450.00 INR".
        #"([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*(?:rs\.?|inr|₹)"#,
    ]

    /// Captures the instrument phrase *and* the last-4 it is attached to, in one
    /// match. Reading them together is what makes the answer trustworthy: a
    /// message can name several instruments ("debited from a/c XX1234 towards
    /// Credit Card payment"), and only the one adjacent to the digits describes
    /// where the money actually moved.
    ///
    /// Group 1 is the instrument phrase, group 2 the digits.
    private static let instrumentLast4Pattern =
        #"((?:credit|debit)\s*card|\bcc\b|\bcard\b|a/?c|acct|account)"#
            + #"\s*(?:no\.?|number|ending(?:\s+(?:in|with))?)?"#
            + #"\s*[x\*]*\s*([0-9]{4})\b"#

    /// Used when no instrument phrase sits next to the digits.
    private static let last4Patterns = [
        #"(?:[x\*]{2,}|\bx)\s*([0-9]{4})\b"#,
        #"ending(?:\s+(?:in|with))?\s*[x\*]*\s*([0-9]{4})\b"#,
    ]

    /// Everything from the anti-fraud footer onwards is noise, and it contains
    /// digits and prepositions that the merchant and last-4 patterns will
    /// happily match — "SMS BLOCK CC 3429 to 7308080808" otherwise reads as a
    /// payment to 7308080808. Cut it before extracting anything.
    private static let boilerplatePatterns = [
        #"not\s+you\s*\??"#,
        #"to\s+block"#,
        #"sms\s+block"#,
        #"call\s+1[0-9]{5,}"#,
        #"to\s+dispute"#,
        #"report\s+(it\s+)?(at|on)"#,
        #"helpline"#,
    ]

    /// The balance clause carries a second, larger figure than the transaction
    /// itself. Amount extraction takes the first match, so a trailing "Avl Bal
    /// Rs 2,300" is usually harmless — but banks are inconsistent about where
    /// they put it, and reading a balance as a spend is the worst mistake this
    /// parser can make. Cut it out rather than rely on ordering.
    ///
    /// The currency token is required, so the phrase alone ("bal enquiry") is
    /// left alone; only a balance *with a figure attached* is removed.
    private static let balanceClausePattern =
        #"\b(?:avl|avbl|avail|available|clear|clr|clos(?:ing)?|a/?c|total)?\.?\s*"#
            + #"bal(?:ance)?\b[^0-9\n]{0,15}(?:rs\.?|inr|₹)\s*[0-9][0-9,]*(?:\.[0-9]{1,2})?"#

    /// Stops at the token that normally follows a merchant in these templates
    /// ("on 28-07-26", "Ref 5123", "UPI"). `at` is tried before `to` because a
    /// message carrying both means the merchant follows `at`.
    private static let merchantPatterns = [
        #"(?:vpa|to\s+vpa)\s+([a-z0-9@._\-]{3,40})"#,
        #"\bat\s+"# + merchantBody,
        #"\b(?:to|towards|in\s+favour\s+of)\s+"# + merchantBody,
    ]

    /// Acquirer-prefixed names ("Ing*REDBUS INDIA PVT L") mean `*` and `/` have
    /// to be inside the class, or the match dies at the first one.
    private static let merchantBody =
        #"([a-z0-9@._\-&'*/, ]{2,40}?)"#
            // A bare "." must not end the match: UPI handles contain them
            // ("cred.telecom@axisb"). Only a sentence-ending period counts.
            + #"(?=\s+on\b|\s+ref\b|\s+upi\b|\s+by\b|\s+dated\b|[;\n]|\.\s|\.$|$)"#

    private static let refPatterns = [
        #"(?:upi\s*)?ref(?:erence)?(?:\s*no\.?)?[:\s#]*([a-z0-9]{4,20})\b"#,
        // "by UPI 657785084827" — no "ref" keyword at all.
        #"\bupi\s+([0-9]{9,20})\b"#,
        #"txn(?:\s*(?:id|no\.?))?[:\s#]*([a-z0-9]{6,20})\b"#,
        #"info[:\s]*([a-z0-9]{4,20})\b"#,
    ]

    /// Tried first: HDFC card alerts use "2026-07-30:14:45:58", which the
    /// day-first pattern below misreads as 30-07-2030 and then discards for
    /// being in the future.
    private static let isoDatePattern =
        #"\b([0-9]{4})-([01][0-9])-([0-3][0-9])\b"#
    private static let numericDatePattern =
        #"\b([0-3]?[0-9])[-/]([01]?[0-9])[-/]([0-9]{2,4})\b"#
    private static let monthNameDatePattern =
        #"\b([0-3]?[0-9])[-\s]([a-z]{3})[-\s]([0-9]{2,4})\b"#
    /// Year-less "On 30-07". The negative lookahead keeps it from matching the
    /// leading half of a full dd-mm-yy date, so it only fires as a last resort.
    private static let dayMonthPattern =
        #"\b([0-3]?[0-9])[-/]([01][0-9])\b(?![-/]?[0-9])"#
    private static let timePattern = #"\b([0-2]?[0-9]):([0-5][0-9])(?::([0-5][0-9]))?\b"#

    private static let monthNames = [
        "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
        "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
    ]

    /// - Parameter now: injected so date resolution is deterministic in tests.
    static func parse(
        _ text: String,
        sender: String,
        now: Date = .now
    ) -> Result<ParsedSMS, SMSRejectReason> {
        let classification: SMSClassification
        switch SMSClassifier.classify(text) {
        case .success(let value): classification = value
        case .failure(let reason): return .failure(reason)
        }

        // Classification looks at the whole message (the footer is harmless
        // there); extraction only ever sees the part before the footer.
        let haystack = stripBoilerplate(text.lowercased())

        guard let amountLiteral = RegexKit.firstCapture(of: amountPatterns, in: haystack),
              let amount = decimalAmount(from: amountLiteral),
              amount > 0
        else { return .failure(.noAmount) }

        // Read from the stripped text, so the anti-fraud footer can't decide the
        // instrument — "SMS BLOCK CC 3429" would otherwise read as a credit card.
        let (instrument, last4) = instrumentAndLast4(in: haystack)
        let merchant = RegexKit.firstCapture(of: merchantPatterns, in: haystack)
            .map(cleanMerchant)
        let refID = RegexKit.firstCapture(of: refPatterns, in: haystack)?.uppercased()

        var parsed = ParsedSMS(
            amount: amount,
            amountLiteral: amountLiteral,
            direction: classification.direction,
            instrument: instrument,
            last4: last4,
            merchant: merchant?.isEmpty == true ? nil : merchant,
            refID: refID,
            date: date(in: haystack, now: now),
            isCardPaymentReceipt: classification.isCardPaymentReceipt,
            rawText: text,
            senderID: sender,
            confidence: 0
        )
        parsed.confidence = confidence(for: parsed)
        return .success(parsed)
    }

    // MARK: Field helpers

    /// Resolves the instrument from the phrase sitting next to the last-4.
    ///
    /// A bare "Card" is read as a credit card: banks name a debit card
    /// explicitly ("Debit Card"), so "HDFC Bank Card 3429" is a credit-card
    /// alert. Falls back to a message-wide scan when the digits carry no
    /// instrument phrase at all.
    private static func instrumentAndLast4(
        in haystack: String
    ) -> (InstrumentKind?, String?) {
        if let groups = RegexKit.firstMatch(instrumentLast4Pattern, in: haystack),
           groups.count > 2,
           let phrase = groups[1]?.replacingOccurrences(
               of: #"\s+"#, with: "", options: .regularExpression
           ),
           let digits = groups[2] {
            let kind: InstrumentKind? = switch phrase {
            case "debitcard": .debitCard
            case "creditcard", "cc": .creditCard
            case "card": .creditCard
            case "a/c", "ac", "acct", "account": .accountNumber
            default: nil
            }
            return (kind, digits)
        }

        return (
            SMSClassifier.instrument(in: haystack),
            RegexKit.firstCapture(of: last4Patterns, in: haystack)
        )
    }

    private static func decimalAmount(from literal: String) -> Double? {
        Double(literal.replacingOccurrences(of: ",", with: ""))
    }

    /// Truncates at the earliest anti-fraud footer marker, then drops any
    /// balance clause left in what remains.
    private static func stripBoilerplate(_ lowercased: String) -> String {
        removingBalanceClause(truncatingAtFooter(lowercased))
    }

    private static func removingBalanceClause(_ text: String) -> String {
        guard let expression = try? NSRegularExpression(
            pattern: balanceClausePattern, options: [.caseInsensitive]
        ) else { return text }
        return expression.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: " "
        )
    }

    private static func truncatingAtFooter(_ lowercased: String) -> String {
        var cut = lowercased.endIndex
        for pattern in boilerplatePatterns {
            guard let expression = try? NSRegularExpression(
                pattern: pattern, options: [.caseInsensitive]
            ) else { continue }
            let range = NSRange(lowercased.startIndex..., in: lowercased)
            guard let match = expression.firstMatch(in: lowercased, range: range),
                  let matchRange = Range(match.range, in: lowercased)
            else { continue }
            cut = min(cut, matchRange.lowerBound)
        }
        return String(lowercased[lowercased.startIndex..<cut])
    }

    /// Drops the payment-acquirer prefix ("Ing*REDBUS INDIA PVT L") and collapses
    /// padding, but keeps the merchant name itself intact — including legal
    /// suffixes like "PVT L". Trimming those is guesswork that loses information,
    /// and the name is editable in the review inbox anyway, so under-cleaning is
    /// the cheaper mistake.
    private static func cleanMerchant(_ raw: String) -> String {
        let value = raw
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(
                of: #"^[a-z0-9]{2,6}\*"#, with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .trimmingCharacters(in: CharacterSet(charactersIn: " .,;:-_'*/"))

        // Title-casing a UPI handle wrecks it ("Cred.Telecom@Axisb"), so those
        // only get their first letter raised.
        guard !value.contains("@") else { return value.capitalizedFirstLetter }
        return value.capitalized
    }

    /// Banks quote the transaction date in the message; falling back to `now` is
    /// safe because the SMS arrives within moments of the transaction.
    private static func date(in haystack: String, now: Date) -> Date {
        var components = DateComponents()

        if let groups = RegexKit.firstMatch(isoDatePattern, in: haystack),
           groups.count > 3,
           let year = groups[1].flatMap(Int.init),
           let month = groups[2].flatMap(Int.init),
           let day = groups[3].flatMap(Int.init) {
            components.year = year
            components.month = month
            components.day = day
        } else if let groups = RegexKit.firstMatch(numericDatePattern, in: haystack),
                  groups.count > 3,
                  let day = groups[1].flatMap(Int.init),
                  let month = groups[2].flatMap(Int.init),
                  let year = groups[3].flatMap(Int.init) {
            components.day = day
            components.month = month
            components.year = fullYear(year)
        } else if let groups = RegexKit.firstMatch(monthNameDatePattern, in: haystack),
                  groups.count > 3,
                  let day = groups[1].flatMap(Int.init),
                  let month = groups[2].flatMap({ monthNames[$0.lowercased()] }),
                  let year = groups[3].flatMap(Int.init) {
            components.day = day
            components.month = month
            components.year = fullYear(year)
        } else if let groups = RegexKit.firstMatch(dayMonthPattern, in: haystack),
                  groups.count > 2,
                  let day = groups[1].flatMap(Int.init),
                  let month = groups[2].flatMap(Int.init) {
            components.day = day
            components.month = month
            components.year = Calendar.current.component(.year, from: now)
        } else {
            return now
        }

        // Use the quoted time when there is one, else the arrival time — a
        // midnight timestamp sorts oddly against manually added transactions.
        if let groups = RegexKit.firstMatch(timePattern, in: haystack),
           groups.count > 2,
           let hour = groups[1].flatMap(Int.init),
           let minute = groups[2].flatMap(Int.init),
           hour < 24 {
            components.hour = hour
            components.minute = minute
        } else {
            let time = Calendar.current.dateComponents([.hour, .minute], from: now)
            components.hour = time.hour
            components.minute = time.minute
        }

        guard let resolved = Calendar.current.date(from: components) else { return now }
        // A parsed date in the future means the day/month order was misread;
        // trust the arrival time instead of booking a future transaction.
        return resolved > now.addingTimeInterval(86_400) ? now : resolved
    }

    private static func fullYear(_ value: Int) -> Int {
        value < 100 ? 2000 + value : value
    }

    /// Confidence reflects how much of the message resolved cleanly. It gates
    /// auto-confirmation, so missing an account identifier — the field needed to
    /// book against the right account — costs the most.
    private static func confidence(for parsed: ParsedSMS) -> Double {
        var score = 0.5
        if parsed.last4 != nil { score += 0.25 }
        if parsed.instrument != nil { score += 0.15 }
        if parsed.merchant != nil { score += 0.05 }
        if parsed.refID != nil { score += 0.05 }
        if !parsed.amountAppearsInRawText { score = 0 }
        return min(score, 1)
    }
}
