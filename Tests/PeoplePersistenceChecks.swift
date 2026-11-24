import Foundation
import SwiftData

@main
struct PeoplePersistenceChecks {
    @MainActor
    static func main() throws {
        let schema = Schema([
            Transaction.self, Account.self, Category.self, Budget.self, RecurringRule.self,
            Person.self, TransactionSplit.self, RecurringSplit.self, CreditGroup.self,
            AccountIdentifier.self, PendingTransaction.self, MerchantRule.self,
        ])
        func container() throws -> ModelContainer {
            try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        }
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
        }
        let original = try container()
        let context = original.mainContext
        let account = Account(name: "Test bank", type: .bank, openingBalance: 1_000)
        let x = Person(name: "X")
        let y = Person(name: "Y")
        let category = Category(name: "Food", type: .expense, symbol: "fork.knife", colorHex: "#000000")
        context.insert(account)
        context.insert(x)
        context.insert(y)
        context.insert(category)
        let settings = SplitSettings(method: .shares, ownShares: 3,
                                     sharesByPerson: [x.id: 2, y.id: 1], participantOrder: [x.id, y.id])
        let bill = Transaction(type: .expense, name: "Dinner", amount: 600, account: account, category: category)
        bill.splitSettings = settings
        context.insert(bill)
        context.insert(TransactionSplit(transaction: bill, person: x, shareAmount: 200))
        context.insert(TransactionSplit(transaction: bill, person: y, shareAmount: 100))
        let oldDebt = Transaction(type: .expense, name: "Previous debt", amount: 50, person: x, isSettlement: true)
        context.insert(oldDebt)
        context.insert(Transaction(type: .expense, name: "Lent", amount: 100, account: account, person: x, isSettlement: true))
        context.insert(Transaction(type: .expense, name: "They paid", amount: 40, category: category, person: x, paidByPerson: true))
        context.insert(Transaction(type: .income, name: "Repaid", amount: 110, account: account, person: x, isSettlement: true))
        let rule = RecurringRule(name: "Shared recurring", amount: 600, account: account)
        rule.splitSettings = settings
        context.insert(rule)
        context.insert(RecurringSplit(rule: rule, person: x, shareAmount: 200))
        context.insert(RecurringSplit(rule: rule, person: y, shareAmount: 100))
        try context.save()
        expect(x.outstanding == 200, "Shares, old debt, lending, borrowed spending and repayments balance correctly")
        expect(y.outstanding == 100, "Other participant's share")
        expect(account.currentBalance == 410, "Previous debt and borrowed spending do not move account balance")
        expect(bill.myShare == 300, "Only your share counts as spending")
        let spending = InsightsService.categoryTotals(in: context, month: .now).reduce(0) { $0 + $1.total }
        expect(spending == 340, "Loans and previous debts stay out of spending")

        let data = try BackupService.exportData(context: context, now: .now)
        let restored = try container()
        try BackupService.importData(data, context: restored.mainContext)
        let restoredBill = try restored.mainContext.fetch(FetchDescriptor<Transaction>()).first { $0.id == bill.id }!
        let restoredRule = try restored.mainContext.fetch(FetchDescriptor<RecurringRule>()).first!
        let restoredX = try restored.mainContext.fetch(FetchDescriptor<Person>()).first { $0.id == x.id }!
        let restoredAccount = try restored.mainContext.fetch(FetchDescriptor<Account>()).first!
        expect(restoredBill.splitSettings == settings, "Transaction method, weights and order survive backup and restore")
        expect(restoredRule.splitSettings == settings, "Recurring method and weights survive backup and restore")
        expect(restoredX.outstanding == 200 && restoredAccount.currentBalance == 410, "Ledger and account balance survive backup and restore")
        let restoredDebt = try restored.mainContext.fetch(FetchDescriptor<Transaction>()).first { $0.id == oldDebt.id }!
        expect(restoredDebt.account == nil && restoredDebt.isSettlement, "Previous debt remains independent of an account")

        // A backup from before this feature has no splitSettings fields.
        var legacy = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        for collection in ["transactions", "recurringRules"] {
            legacy[collection] = (legacy[collection] as! [[String: Any]]).map { entry in
                var entry = entry
                entry.removeValue(forKey: "splitSettings")
                return entry
            }
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let legacySnapshot = try decoder.decode(SyncSnapshot.self, from: JSONSerialization.data(withJSONObject: legacy))
        expect(legacySnapshot.transactions.allSatisfy { $0.splitSettings == nil }, "Old transaction backups decode")
        expect(legacySnapshot.recurringRules.allSatisfy { $0.splitSettings == nil }, "Old recurring backups decode")
        print("People persistence checks passed (ledger, old debt, balances, analytics, backup/restore and legacy decoding).")
    }
}
