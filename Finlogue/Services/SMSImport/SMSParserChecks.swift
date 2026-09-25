//
//  SMSParserChecks.swift
//  Finlogue
//
//  Debug-only fixture run for the SMS pipeline. There is no unit-test target, so
//  this is the harness: launch with `-runSMSParserChecks` and read the console.
//
//  The OTP cases matter most — an HDFC card OTP carries an amount, a merchant
//  and a card last-4, so it is the message most likely to be mis-booked.
//

#if DEBUG
import Foundation
import SwiftData

enum SMSParserChecks {

    private struct Fixture {
        let sender: String
        let text: String
        /// nil means "must be rejected".
        let expectedAmount: Double?
        let expectedInstrument: InstrumentKind?
        let note: String
        /// Asserted when set — used where a template previously mis-extracted.
        var expectedMerchant: String?
        var expectedLast4: String?
        /// Local-time "yyyy-MM-dd HH:mm", asserted when set.
        var expectedTimestamp: String?
        /// Local-time "yyyy-MM-dd", for messages that quote no time of day.
        var expectedDay: String?
    }

    private static let fixtures: [Fixture] = [
        // MARK: Must be rejected
        Fixture(
            sender: "VM-HDFCBK-T",
            text: "OTP is 481920 for txn of Rs 2,499.00 at AMAZON on card ending 5678. Valid for 10 mins. Do not share this OTP.",
            expectedAmount: nil,
            expectedInstrument: nil,
            note: "Card OTP quoting amount + merchant + last4"
        ),
        Fixture(
            sender: "VM-HDFCBK-T",
            text: "Use OTP 334455 to authorise a payment of INR 899 on your HDFC Bank Credit Card XX5678.",
            expectedAmount: nil,
            expectedInstrument: nil,
            note: "OTP phrased as authorisation"
        ),
        Fixture(
            sender: "AD-AXISBK-P",
            text: "Congratulations! You are pre-approved for a personal loan of Rs 5,00,000. Apply now at axisb.co/xyz. T&C apply.",
            expectedAmount: nil,
            expectedInstrument: nil,
            note: "Promotional"
        ),
        Fixture(
            sender: "VM-HDFCBK-S",
            text: "Avl Bal in your A/c XX1234 as on 28-07-26 is Rs 45,120.55.",
            expectedAmount: nil,
            expectedInstrument: nil,
            note: "Balance enquiry"
        ),
        Fixture(
            sender: "VM-HDFCBK-S",
            text: "Your HDFC Bank Credit Card XX5678 statement is generated. Total due Rs 12,400.00, min due Rs 620.00, due on 15-08-2026.",
            expectedAmount: nil,
            expectedInstrument: nil,
            note: "Statement — would double-count"
        ),
        Fixture(
            sender: "VM-HDFCBK-S",
            text: "Rs 2,500.00 will be debited from your A/c XX1234 on 01-08-26 towards SIP mandate.",
            expectedAmount: nil,
            expectedInstrument: nil,
            note: "Future-tense mandate notice"
        ),
        Fixture(
            sender: "VM-HDFCBK-T",
            text: "Transaction of Rs 1,200.00 on your Credit Card XX5678 at BIGBASKET has been declined.",
            expectedAmount: nil,
            expectedInstrument: nil,
            note: "Declined"
        ),

        // MARK: Must parse
        Fixture(
            sender: "VM-HDFCBK-S",
            text: "Rs.450.00 debited from a/c XX1234 on 28-07-26 to VPA swiggy@ybl. UPI Ref 512345678901. Not you? Call 18002586161.",
            expectedAmount: 450,
            expectedInstrument: .accountNumber,
            note: "UPI debit from bank account"
        ),
        Fixture(
            sender: "VM-HDFCBK-T",
            text: "Alert: You've spent Rs.2499.00 via Credit Card XX5678 at AMAZON on 28-07-2026.",
            expectedAmount: 2499,
            expectedInstrument: .creditCard,
            note: "Credit card spend"
        ),
        Fixture(
            sender: "VM-HDFCBK-S",
            text: "Rs 780.50 spent via Debit Card XX9012 at RELIANCE FRESH on 27-07-26.",
            expectedAmount: 780.5,
            expectedInstrument: .debitCard,
            note: "Debit card spend — hits the bank account, different last4"
        ),
        Fixture(
            sender: "AD-AXISBK-S",
            text: "INR 513.00 debited\nA/c no. XX8354\n03-08-26, 14:04:32\nUPI/P2M/658141198354/Amazon Pay on Deliv\nNot you? SMS BLOCKUPI Cust ID to 919951860002\nAxis Bank",
            expectedAmount: 513,
            expectedInstrument: .accountNumber,
            // Merchant and ref sit inside the UPI/P2M/<ref>/<name> block, which
            // no pattern reads yet — the row files as "Card Spend" until one
            // does. Amount, account and timestamp are what matter for booking.
            note: "Axis UPI debit: leading INR, line-broken template",
            expectedLast4: "8354",
            expectedTimestamp: "2026-08-03 14:04"
        ),
        Fixture(
            sender: "VM-SBIINB-S",
            text: "Dear Customer, your A/c XX1234 is debited by Rs.500.00 on 03-08-26 transfer to AMAZON. Avl Bal Rs 2,300.00 -SBI",
            expectedAmount: 500,
            expectedInstrument: .accountNumber,
            // The balance clause used to reject this outright, and its larger
            // figure must not become the amount.
            note: "Debit alert carrying a running balance",
            expectedLast4: "1234"
        ),
        Fixture(
            sender: "AD-ICICIB-S",
            text: "Acct XX4321 credited with INR 15,000.00 on 03-Aug-26. Avl Bal: INR 47,890.12. Info: SALARY JULY.",
            expectedAmount: 15000,
            expectedInstrument: .accountNumber,
            note: "Credit alert carrying a running balance",
            expectedLast4: "4321"
        ),
        Fixture(
            sender: "AD-AXISBK-S",
            text: "INR 15,000.00 credited to your Axis Bank A/c no. XX4321 on 25-07-2026. Info: SALARY JULY.",
            expectedAmount: 15000,
            expectedInstrument: .accountNumber,
            note: "Salary credit"
        ),
        Fixture(
            sender: "AD-AXISBK-S",
            text: "Rs 1,499.00 refunded to your Axis Bank Credit Card no. XX7788 by FLIPKART on 26-07-2026.",
            expectedAmount: 1499,
            expectedInstrument: .creditCard,
            note: "Refund reduces card outstanding"
        ),
        Fixture(
            sender: "VM-HDFCBK-T",
            text: "Spent Rs.639 On HDFC Bank Card 3429 At Ing*REDBUS INDIA PVT L On 2026-07-30:14:45:58.Not You? To Block+Reissue Call 18002586161/SMS BLOCK CC 3429 to 7308080808",
            expectedAmount: 639,
            // Bare "Card" next to the digits means credit card — HDFC says
            // "Debit Card" when it means one.
            expectedInstrument: .creditCard,
            note: "HDFC card alert: acquirer prefix, ISO timestamp, fraud footer",
            expectedMerchant: "Redbus India Pvt L",
            expectedLast4: "3429",
            expectedTimestamp: "2026-07-30 14:45"
        ),
        Fixture(
            sender: "VM-HDFCBK-S",
            text: "Rs 15,000.00 debited from a/c XX1234 on 27-07-26 towards HDFC Credit Card payment. Ref 700100200300.",
            expectedAmount: 15000,
            // Names two instruments; only the one next to the digits counts.
            expectedInstrument: .accountNumber,
            note: "Card payment names two instruments — digits decide",
            expectedLast4: "1234"
        ),
        Fixture(
            sender: "JM-HDFCBK-S",
            text: "Txn Rs.53.00\nOn HDFC Bank Card 9312\nAt cred.telecom@axisb\nby UPI 657785084827\nOn 30-07\nNot You?\nCall 18002586161/SMS BLOCK CC 9312 to 7308080808",
            expectedAmount: 53,
            expectedInstrument: .creditCard,
            note: "HDFC UPI-on-card: \"Txn\" verb, day-month date, UPI ref",
            expectedMerchant: "Cred.telecom@axisb",
            expectedLast4: "9312",
            expectedDay: "2026-07-30"
        ),
        Fixture(
            sender: "VM-HDFCBK-S",
            text: "Txn Rs.170.00\nOn HDFC Bank Card 9312\nAt q921664372@ybl\nby UPI 621189184954\nOn 30-07\nNot You?\nCall 18002586161/SMS BLOCK CC 9312 to 7308080808",
            expectedAmount: 170,
            expectedInstrument: .creditCard,
            note: "Same template, digit-leading UPI handle",
            expectedMerchant: "Q921664372@ybl",
            expectedLast4: "9312",
            expectedDay: "2026-07-30"
        ),
    ]

    /// Also written to `Documents/sms-parser-checks.txt`, because the simulator
    /// console is unreliable to capture when the app is launched headlessly.
    /// The ingest checks build their own `TransactionStore`, whose initialiser
    /// also honours the launch argument — without this guard that recurses.
    @MainActor private static var isRunning = false

    @MainActor
    static func run() {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        var lines = ["── SMS parser checks ──"]
        var passed = 0
        var failed = 0

        for fixture in fixtures {
            let result = SMSTransactionParser.parse(fixture.text, sender: fixture.sender)
            let outcome = evaluate(fixture, result)
            if outcome.ok { passed += 1 } else { failed += 1 }
            lines.append("\(outcome.ok ? "PASS" : "FAIL") [\(fixture.sender)] \(fixture.note)")
            if !outcome.ok { lines.append("     -> \(outcome.detail)") }
        }
        lines.append("── \(passed) passed, \(failed) failed ──")

        lines.append(contentsOf: ingestChecks())

        let report = lines.joined(separator: "\n")
        print(report)
        if let documents = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first {
            try? report.write(
                to: documents.appendingPathComponent("sms-parser-checks.txt"),
                atomically: true,
                encoding: .utf8
            )
        }
    }

    // MARK: End-to-end ingest

    /// Exercises resolution, duplicate suppression and card-payment pairing
    /// against a throwaway in-memory store, so the real ledger is untouched.
    @MainActor
    private static func ingestChecks() -> [String] {
        var lines = ["", "── SMS ingest checks ──"]

        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true, allowsSave: true
        )
        guard let container = try? ModelContainer(
            for: AppModelContainer.schema, configurations: [configuration]
        ) else { return lines + ["FAIL could not build in-memory container"] }

        let store = TransactionStore(container: container)
        let context = store.context

        let savings = Account(name: "HDFC Savings", type: .bank, openingBalance: 50_000)
        let card = Account(
            name: "HDFC Credit Card", type: .creditCard, creditLimit: 200_000
        )
        context.insert(savings)
        context.insert(card)
        context.insert(
            AccountIdentifier(last4: "1234", kind: .accountNumber, account: savings)
        )
        context.insert(
            AccountIdentifier(last4: "9012", kind: .debitCard, account: savings)
        )
        context.insert(
            AccountIdentifier(last4: "5678", kind: .creditCard, account: card)
        )
        try? context.save()

        func check(_ label: String, _ passed: Bool, _ detail: String = "") {
            lines.append("\(passed ? "PASS" : "FAIL") \(label)")
            if !passed, !detail.isEmpty { lines.append("     -> \(detail)") }
        }

        // Resolution: the debit-card last-4 must land on the bank account, not a
        // card account of its own.
        let debitCardSwipe = SMSImportService.ingest(
            text: "Rs 780.50 spent via Debit Card XX9012 at RELIANCE FRESH on 27-07-26.",
            sender: "VM-HDFCBK-S", store: store
        )
        if case .queued(let pending) = debitCardSwipe {
            check(
                "debit card resolves to bank account",
                pending.resolvedAccountID == savings.id,
                "resolved to \(pending.resolvedAccountID?.uuidString ?? "nil")"
            )
        } else {
            check("debit card resolves to bank account", false, "\(debitCardSwipe)")
        }

        // Duplicate: banks send a card alert and a merchant alert for one swipe.
        let duplicate = SMSImportService.ingest(
            text: "Rs 780.50 spent via Debit Card XX9012 at RELIANCE FRESH on 27-07-26.",
            sender: "VM-HDFCBK-S", store: store
        )
        if case .duplicate = duplicate {
            check("second alert for one swipe is dropped", true)
        } else {
            check("second alert for one swipe is dropped", false, "\(duplicate)")
        }

        // Unknown digits must ask rather than guess.
        let unknown = SMSImportService.ingest(
            text: "Rs 300.00 debited from a/c XX7777 on 27-07-26 to VPA test@ybl. Ref 999888777666.",
            sender: "VM-HDFCBK-S", store: store
        )
        if case .queued(let pending) = unknown {
            check("unknown digits ask for an account", pending.needsAccountChoice)
        } else {
            check("unknown digits ask for an account", false, "\(unknown)")
        }

        // Card payment: two messages, one transfer.
        let bankLeg = SMSImportService.ingest(
            text: "Rs 15,000.00 debited from a/c XX1234 on 27-07-26 towards HDFC Credit Card payment. Ref 700100200300.",
            sender: "VM-HDFCBK-S", store: store
        )
        let cardLeg = SMSImportService.ingest(
            text: "Payment of Rs 15,000.00 received on your HDFC Bank Credit Card XX5678 on 27-07-26.",
            sender: "VM-HDFCBK-S", store: store
        )
        if case .pairedIntoTransfer(let merged) = cardLeg {
            check(
                "card payment pairs into one transfer",
                merged.type == .transfer
                    && merged.resolvedAccountID == savings.id
                    && merged.resolvedToAccountID == card.id,
                "type \(merged.typeRaw), from \(merged.resolvedAccountID == savings.id), "
                    + "to \(merged.resolvedToAccountID == card.id)"
            )
        } else {
            check(
                "card payment pairs into one transfer", false,
                "bank leg \(bankLeg), card leg \(cardLeg)"
            )
        }

        return lines
    }

    private static func evaluate(
        _ fixture: Fixture,
        _ result: Result<ParsedSMS, SMSRejectReason>
    ) -> (ok: Bool, detail: String) {
        switch (result, fixture.expectedAmount) {
        case (.failure, nil):
            return (true, "")
        case (.failure(let reason), .some(let expected)):
            return (false, "expected \(expected), was rejected as \(reason.rawValue)")
        case (.success(let parsed), nil):
            return (
                false,
                "expected rejection, parsed \(parsed.amount) "
                    + "\(parsed.instrument?.rawValue ?? "unknown") "
                    + "\(parsed.merchant ?? "-")"
            )
        case (.success(let parsed), .some(let expected)):
            var problems: [String] = []
            if parsed.amount != expected {
                problems.append("amount \(parsed.amount) != \(expected)")
            }
            if parsed.instrument != fixture.expectedInstrument {
                problems.append(
                    "instrument \(parsed.instrument?.rawValue ?? "nil") != "
                        + "\(fixture.expectedInstrument?.rawValue ?? "nil")"
                )
            }
            if parsed.last4 == nil { problems.append("no last4") }
            if !parsed.amountAppearsInRawText { problems.append("amount not in raw text") }
            if let expected = fixture.expectedMerchant, parsed.merchant != expected {
                problems.append("merchant \(parsed.merchant ?? "nil") != \(expected)")
            }
            if let expected = fixture.expectedLast4, parsed.last4 != expected {
                problems.append("last4 \(parsed.last4 ?? "nil") != \(expected)")
            }
            if let expected = fixture.expectedTimestamp {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm"
                let actual = formatter.string(from: parsed.date)
                if actual != expected {
                    problems.append("date \(actual) != \(expected)")
                }
            }
            if let expected = fixture.expectedDay {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let actual = formatter.string(from: parsed.date)
                if actual != expected {
                    problems.append("day \(actual) != \(expected)")
                }
            }
            return (problems.isEmpty, problems.joined(separator: ", "))
        }
    }
}
#endif
