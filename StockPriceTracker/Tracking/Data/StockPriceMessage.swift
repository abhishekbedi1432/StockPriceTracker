//
//  StockPriceMessage.swift
//  StockPriceTracker
//
//  Created by Abhishek on 02/11/2026.
//

import Foundation

struct StockPriceMessage: Codable, Sendable {
    let symbol: String
    let price: Decimal
}
