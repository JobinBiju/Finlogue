//
//  Account.swift
//  ExpenseTracker
//
//  Created by Jobin Biju on 18/04/25.
//

import Foundation
import SwiftUI
import SwiftData

@Model
class Account {
    var id: UUID = UUID()
    var name: String
    var balance: Double
    
    init(name: String, balance: Double) {
        self.name = name
        self.balance = balance
    }
}
