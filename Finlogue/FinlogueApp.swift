//
//  ExpenseTrackerApp.swift
//  ExpenseTracker
//
//  Created by Jobin Biju on 18/04/25.
//

import SwiftUI

@main
struct FinlogueApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .modelContainer(for: [Transaction.self, Account.self, Category.self])
        }
    }
}
