import Foundation
import Testing
@testable import StockPriceTracker

@MainActor
struct PriceSimulatorCatalogTests {
    @Test
    func makeInitialStocksCreatesTwentyFiveUniqueSymbols() {
        let stocks = PriceSimulator.makeInitialStocks(currencyCode: "USD")

        #expect(stocks.count == 25)
        #expect(Set(stocks.map(\.symbol)).count == 25)
        #expect(stocks.allSatisfy { $0.currencyCode == "USD" })
        #expect(stocks.allSatisfy { $0.change == 0 })
        #expect(stocks.allSatisfy { $0.price >= 100 && $0.price <= 500 })
        #expect(stocks.allSatisfy { !$0.name.isEmpty })
    }

    @Test
    func makeUpdatesReturnsEmptyBatchForEmptyInput() {
        #expect(PriceSimulator.makeUpdates(for: []).isEmpty)
    }

    @Test
    func makeUpdatesSelectsDistinctSymbolsWithinBounds() {
        let stocks = [
            Stock(symbol: "AAPL", name: "Apple", description: "A", currencyCode: "USD", price: 100, change: 0),
            Stock(symbol: "MSFT", name: "Microsoft", description: "M", currencyCode: "USD", price: 200, change: 0),
            Stock(symbol: "GOOG", name: "Alphabet", description: "G", currencyCode: "USD", price: 300, change: 0)
        ]

        let updates = PriceSimulator.makeUpdates(for: stocks)

        #expect((2...3).contains(updates.count))
        #expect(Set(updates.map(\.symbol)).count == updates.count)
        #expect(Set(stocks.map(\.symbol)).isSuperset(of: Set(updates.map(\.symbol))))
        #expect(updates.allSatisfy { $0.price >= Decimal(1) / 100 })
    }
}
