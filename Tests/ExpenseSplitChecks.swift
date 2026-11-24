import Foundation

@main
struct ExpenseSplitChecks {
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
    }

    static func main() throws {
        expect(ExpenseSplit.allocate(total: 600, weights: [3, 2, 1]) == [300, 200, 100], "3:2:1 shares")
        expect(ExpenseSplit.allocate(total: 100, weights: [1, 1, 1]) == [33.34, 33.33, 33.33], "Equal split rounds to the full bill")
        expect(ExpenseSplit.allocate(total: 0.01, weights: [0, 1, 1]) == [0, 0.01, 0], "Excluded people never receive rounding remainder")
        expect(ExpenseSplit.allocate(total: 90, weights: [0.5, 1, 1.5]) == [15, 30, 45], "Fractional weights")
        expect(ExpenseSplit.allocate(total: 0, weights: [1, 2]) == [0, 0], "Split can be set up before entering total")
        expect(ExpenseSplit.allocate(total: 100, weights: [0, 0]) == nil, "All-zero shares rejected")
        expect(ExpenseSplit.allocate(total: 100, weights: [-1, 2]) == nil, "Negative shares rejected")
        expect(ExpenseSplit.allocate(total: 100, weights: [.infinity, 1]) == nil, "Infinite shares rejected")
        expect(ExpenseSplit.allocate(total: .nan, weights: [1, 1]) == nil, "NaN total rejected")
        expect(ExpenseSplit.allocate(total: -1, weights: [1, 1]) == nil, "Negative bill rejected")

        let x = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let y = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        var plan = SplitPlan()
        plan.participants = [SplitDraft(personID: x, amount: 200, shares: 2), SplitDraft(personID: y, amount: 100)]
        expect(plan.amounts(total: 600) == [300, 200, 100], "Exact amounts leave your remainder")
        expect(plan.amounts(total: 299) == nil, "Overallocated exact split rejected after reducing bill")
        plan.method = .shares
        plan.ownShares = 3
        expect(plan.amounts(total: 600) == [300, 200, 100], "User's requested weighted example")
        expect(plan.amounts(total: 660) == [330, 220, 110], "Fees and amount edits preserve ratio")
        expect(plan.amounts(total: 1_200) == [600, 400, 200], "Bill total edits recalculate")
        let settings = try JSONDecoder().decode(SplitSettings.self, from: JSONEncoder().encode(plan.settings))
        let reversed = Array(plan.resolved(total: 600)!.reversed())
        let restored = SplitPlan(participants: reversed, settings: settings)
        expect(restored.method == .shares && restored.ownShares == 3, "Method and your shares persist")
        expect(restored.participants.map(\.personID) == [x, y], "Rounding order survives relationship reordering")
        expect(restored.amounts(total: 660) == [330, 220, 110], "Participant weights persist")
        plan.select(.exact, total: 660)
        expect(plan.amounts(total: 660) == [330, 220, 110], "Switching to exact preserves allocations")
        plan.select(.equal, total: 100)
        expect(plan.amounts(total: 100) == [33.34, 33.33, 33.33], "Switching to equal includes you")
        plan.ownShares = 0
        expect(plan.amounts(total: 100) == [0, 50, 50], "Equal split can exclude you")
        expect(plan.resolved(total: 0.01)?.count == 2, "Tiny bills retain participants whose amount rounds to zero")
        plan.select(.exact, total: 0.01)
        expect(plan.resolved(total: 0.01)?.count == 1, "Exact splits omit zero debts")
        expect(SplitSettings(data: nil).method == .exact, "Legacy splits default to exact amounts")

        // Exercise rounding across uneven weights, zero participants and small
        // totals. Each allocation must stay within one minor unit of its quota.
        for count in 1...12 {
            for seed in 1...150 {
                let weights = (0..<count).map { Double((seed * ($0 + 7)) % 13) / 2 }
                guard weights.reduce(0, +) > 0 else { continue }
                let cents = Int64(seed * 73)
                let amounts = ExpenseSplit.allocate(total: Double(cents) / 100, weights: weights)!
                let allocated = amounts.map { ExpenseSplit.minorUnits($0)! }
                expect(allocated.reduce(0, +) == cents, "No money lost or created by rounding")
                for index in weights.indices {
                    let quota = Double(cents) * weights[index] / weights.reduce(0, +)
                    expect(abs(Double(allocated[index]) - quota) < 1.000001, "Allocation stays near proportional quota")
                    if weights[index] == 0 { expect(allocated[index] == 0, "Zero shares stay zero") }
                }
            }
        }
        print("Expense split checks passed (exact, equal, weighted, rounding, validation, editing and persistence).")
    }
}
