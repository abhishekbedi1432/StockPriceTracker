//
//  StockTests.swift
//  StockPriceTrackerTests
//
//  Created by Abhishek on 02/11/2026.
//

import Foundation
import Testing
@testable import StockPriceTracker

@MainActor
struct StockTests {
    @Test
    func applyingPricesCalculatesChangeFromPreviousPrice() {
        var stock = Stock(
            symbol: "AAPL",
            name: "Apple",
            description: "Test stock",
            currencyCode: "USD",
            price: 100,
            change: 0
        )

        stock.applyPrice(105)

        #expect(stock.price == 105)
        #expect(stock.change == 5)

        stock.applyPrice(103)

        #expect(stock.price == 103)
        #expect(stock.change == -2)

        stock.applyPrice(103)

        #expect(stock.price == 103)
        #expect(stock.change == 0)
    }
}
