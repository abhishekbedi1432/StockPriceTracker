import Foundation
import Testing
@testable import StockPriceTracker

@MainActor
struct StockSortOptionTests {
    @Test
    func sortsPricesFromHighestToLowest() {
        let stocks = [
            makeStock("AAPL", price: 100),
            makeStock("MSFT", price: 250),
            makeStock("GOOG", price: Decimal(10001) / 100)
        ]

        let sorted = StockSortOption.price.sort(stocks)

        #expect(sorted.map(\.symbol) == ["MSFT", "GOOG", "AAPL"])
        #expect(stocks.map(\.symbol) == ["AAPL", "MSFT", "GOOG"])
    }

    @Test
    func sortsChangesBySignedValueRatherThanMagnitude() {
        let stocks = [
            makeStock("AAPL", change: -10),
            makeStock("MSFT", change: 2),
            makeStock("GOOG", change: 0),
            makeStock("NVDA", change: -1)
        ]

        let sorted = StockSortOption.change.sort(stocks)

        #expect(sorted.map(\.symbol) == ["MSFT", "GOOG", "NVDA", "AAPL"])
    }

    @Test(arguments: [StockSortOption.price, .change])
    func breaksTiesAlphabeticallyBySymbol(option: StockSortOption) {
        let stocks = [
            makeStock("MSFT", price: 100, change: 2),
            makeStock("GOOG", price: 100, change: 2),
            makeStock("AAPL", price: 100, change: 2)
        ]

        #expect(option.sort(stocks).map(\.symbol) == ["AAPL", "GOOG", "MSFT"])
        #expect(option.sort(Array(stocks.reversed())).map(\.symbol) == ["AAPL", "GOOG", "MSFT"])
    }

    @Test(arguments: [StockSortOption.price, .change])
    func handlesEmptyAndSingleStockLists(option: StockSortOption) {
        let stock = makeStock("AAPL")

        #expect(option.sort([]).isEmpty)
        #expect(option.sort([stock]) == [stock])
    }

    private func makeStock(
        _ symbol: String,
        price: Decimal = 100,
        change: Decimal = 0
    ) -> Stock {
        Stock(
            symbol: symbol,
            name: symbol,
            description: "Test stock",
            currencyCode: "USD",
            price: price,
            change: change
        )
    }
}
