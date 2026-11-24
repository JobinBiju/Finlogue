import Foundation

struct SplitDraft: Identifiable, Equatable {
    let id: UUID
    var personID: UUID
    var amount: Double
    var shares: Double

    init(id: UUID = UUID(), personID: UUID, amount: Double = 0, shares: Double = 1) {
        self.id = id
        self.personID = personID
        self.amount = amount
        self.shares = shares
    }
}

/// Editor state. Calculated amounts are derived from the current total rather
/// than cached, so changing the amount or fees cannot leave stale allocations.
struct SplitPlan: Equatable {
    var method: SplitMethod = .exact
    var ownShares: Double = 1
    var participants: [SplitDraft] = []

    init(participants: [SplitDraft] = [], settings: SplitSettings = SplitSettings()) {
        method = settings.method
        ownShares = settings.ownShares
        self.participants = participants.sorted {
            let lhs = settings.participantOrder.firstIndex(of: $0.personID) ?? Int.max
            let rhs = settings.participantOrder.firstIndex(of: $1.personID) ?? Int.max
            return lhs == rhs ? $0.personID.uuidString < $1.personID.uuidString : lhs < rhs
        }.map { draft in
            var draft = draft
            draft.shares = settings.sharesByPerson[draft.personID] ?? 1
            return draft
        }
    }

    /// Your amount is first, followed by one amount per participant.
    func amounts(total: Double) -> [Double]? {
        guard let totalCents = ExpenseSplit.minorUnits(total) else { return nil }
        if method == .exact {
            let cents = participants.compactMap { ExpenseSplit.minorUnits($0.amount) }
            guard cents.count == participants.count else { return nil }
            var remaining = totalCents
            for amount in cents {
                guard amount <= remaining else { return nil }
                remaining -= amount
            }
            return ([remaining] + cents).map { Double($0) / 100 }
        }
        let weights = method == .equal
            ? [ownShares > 0 ? 1.0 : 0.0] + participants.map { _ in 1.0 }
            : [ownShares] + participants.map(\.shares)
        return ExpenseSplit.allocate(total: total, weights: weights)
    }

    func resolved(total: Double) -> [SplitDraft]? {
        guard let amounts = amounts(total: total) else { return nil }
        return participants.enumerated().compactMap { index, draft in
            var result = draft
            result.amount = amounts[index + 1]
            // Retain zero allocations in calculated splits: a tiny bill may
            // round someone to zero, but they still participate when it grows.
            return method == .exact && result.amount == 0 ? nil : result
        }
    }

    var settings: SplitSettings {
        SplitSettings(
            method: method, ownShares: ownShares.isFinite && ownShares >= 0 ? ownShares : 1,
            sharesByPerson: Dictionary(participants.map {
                ($0.personID, $0.shares.isFinite && $0.shares >= 0 ? $0.shares : 1)
            }, uniquingKeysWith: { _, new in new }),
            participantOrder: participants.map(\.personID)
        )
    }

    mutating func select(_ method: SplitMethod, total: Double) {
        if method == .exact, let amounts = amounts(total: total) {
            for index in participants.indices { participants[index].amount = amounts[index + 1] }
        }
        self.method = method
    }
}
