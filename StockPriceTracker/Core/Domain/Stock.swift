//
//  Stock.swift
//  StockPriceTracker
//
//  Created by Abhishek on 02/11/2026.
//

import Foundation
struct Stock: Identifiable, Equatable, Sendable {
    let symbol: String
    let name: String
    let description: LocalizedStringResource
    let currencyCode: String

    var price: Decimal
    var change: Decimal

    var id: String { symbol }
    
    
    mutating func applyPrice(_ newPrice: Decimal) {
        change = newPrice - price
        price = newPrice
    }
}

