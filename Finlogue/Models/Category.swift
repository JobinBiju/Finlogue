//
//  Category.swift
//  ExpenseTracker
//
//  Created by Jobin Biju on 18/04/25.
//

import Foundation
import SwiftUI
import SwiftData

@Model
class Category {
    var id: UUID = UUID()
    var name: String
    var type: TransactionType
    
    init(name: String, type: TransactionType) {
        self.name = name
        self.type = type
    }
}
