//
//  StockDetailViewModel.swift
//  StockPriceTracker
//
//  Created by Abhishek on 02/11/2026.
//

import Foundation

import Observation

@MainActor
@Observable
final class StockDetailViewModel {
    let symbol: String

    private let tracking: StockTrackingService

    init(
        symbol: String,
        tracking: StockTrackingService
    ) {
        self.symbol = symbol
        self.tracking = tracking
    }

    var stock: Stock? {
        tracking.stocks.first {
            $0.symbol == symbol
        }
    }
}
