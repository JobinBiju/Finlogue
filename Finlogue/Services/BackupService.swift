//
//  BackupService.swift
//  Finlogue
//
//  Full-fidelity export/import of the entire store as a JSON file — the safe
//  way to move data across a signing-team / bundle-id change, plus a general
//  backup. Reuses the sync DTOs; unlike the watch snapshot it never trims.
//

import Foundation
import SwiftData

enum BackupService {
    static let fileExtension = "finlogue"

    /// A timestamped filename for the exported backup.
    static func suggestedFilename(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "Finlogue-Backup-\(formatter.string(from: date)).\(fileExtension)"
    }

    // MARK: Export

    /// Serializes the entire store to pretty JSON. Includes every transaction
    /// (no snapshot trimming) so nothing is lost.
    @MainActor
    static func exportData(context: ModelContext, now: Date) throws -> Data {
        let accounts = try context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.createdAt)]))
        let creditGroups = try context.fetch(FetchDescriptor<CreditGroup>(sortBy: [SortDescriptor(\.name)]))
        let categories = try context.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.sortOrder)]))
        let budgets = try context.fetch(FetchDescriptor<Budget>())
        let rules = try context.fetch(FetchDescriptor<RecurringRule>(sortBy: [SortDescriptor(\.name)]))
        let people = try context.fetch(FetchDescriptor<Person>(sortBy: [SortDescriptor(\.name)]))
        let splits = try context.fetch(FetchDescriptor<TransactionSplit>())
        let recurringSplits = try context.fetch(FetchDescriptor<RecurringSplit>())
        let transactions = try context.fetch(
            FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        )

        let snapshot = SyncSnapshot(
            generatedAt: now,
            currencyCode: AppSettings.currencyCode,
            themeID: ThemeManager.shared.theme.rawValue,
            accounts: accounts.map(AccountDTO.init),
            categories: categories.map(CategoryDTO.init),
            budgets: budgets.map(BudgetDTO.init),
            recurringRules: rules.map(RecurringRuleDTO.init),
            transactions: transactions.map(TransactionDTO.init),
            people: people.map(PersonDTO.init),
            splits: splits.map(TransactionSplitDTO.init),
            creditGroups: creditGroups.map(CreditGroupDTO.init),
            recurringSplits: recurringSplits.map(RecurringSplitDTO.init)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }

    /// Writes an export to a temporary file and returns its URL (for a share sheet).
    @MainActor
    static func writeExport(context: ModelContext, now: Date) throws -> URL {
        let data = try exportData(context: context, now: now)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(suggestedFilename(date: now))
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: Import

    /// Replaces the current store with the backup's contents (upsert everything
    /// present, delete everything missing) and restores currency + theme.
    @MainActor
    static func importData(_ data: Data, context: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let snapshot = try decoder.decode(SyncSnapshot.self, from: data)
        try SnapshotBuilder.apply(snapshot, context: context)
    }
}
