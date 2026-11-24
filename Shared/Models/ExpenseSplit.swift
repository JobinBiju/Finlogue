import Foundation

enum SplitMethod: String, Codable, CaseIterable, Identifiable {
    case exact, equal, shares

    var id: String { rawValue }
    var label: String {
        switch self {
        case .exact: "Exact"
        case .equal: "Equal"
        case .shares: "Shares"
        }
    }
}

/// The calculation inputs, saved alongside the actual monetary split rows so
/// editing a bill's amount can preserve an equal split or a ratio such as 3:2:1.
struct SplitSettings: Codable, Equatable {
    var method: SplitMethod = .exact
    var ownShares: Double = 1
    var sharesByPerson: [UUID: Double] = [:]
    var participantOrder: [UUID] = []

    init(
        method: SplitMethod = .exact, ownShares: Double = 1,
        sharesByPerson: [UUID: Double] = [:], participantOrder: [UUID] = []
    ) {
        self.method = method
        self.ownShares = ownShares
        self.sharesByPerson = sharesByPerson
        self.participantOrder = participantOrder
    }

    init(data: Data?) {
        self = data.flatMap { try? JSONDecoder().decode(Self.self, from: $0) } ?? Self()
    }

    var data: Data? { try? JSONEncoder().encode(self) }
}

enum ExpenseSplit {
    /// All displayed money uses two fractional digits. Calculate in minor units
    /// and distribute rounding remainders so the shares always add to the bill.
    static func minorUnits(_ amount: Double) -> Int64? {
        guard amount.isFinite, amount >= 0, amount <= 90_000_000_000 else { return nil }
        return Int64((amount * 100).rounded())
    }

    static func allocate(total: Double, weights: [Double]) -> [Double]? {
        guard let cents = minorUnits(total), !weights.isEmpty,
              weights.allSatisfy({ $0.isFinite && $0 >= 0 }) else { return nil }
        let sum = weights.reduce(0, +)
        guard sum.isFinite, sum > 0 else { return nil }
        let portions = weights.map { Double(cents) * ($0 / sum) }
        var units = portions.map { Int64($0.rounded(.down)) }
        let remainder = cents - units.reduce(0, +)
        guard remainder >= 0, remainder <= weights.count else { return nil }
        // Largest remainder first; ties are stable in participant order.
        let order = weights.indices.filter { weights[$0] > 0 }.sorted {
            let lhs = portions[$0] - Double(units[$0])
            let rhs = portions[$1] - Double(units[$1])
            return lhs == rhs ? $0 < $1 : lhs > rhs
        }
        guard remainder <= order.count else { return nil }
        for index in order.prefix(Int(remainder)) { units[index] += 1 }
        return units.map { Double($0) / 100 }
    }
}
