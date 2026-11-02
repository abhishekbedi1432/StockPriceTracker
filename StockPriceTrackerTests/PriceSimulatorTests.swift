import Foundation
import Testing
@testable import StockPriceTracker

@MainActor
struct PriceSimulatorTests {
    @Test(arguments: [
        (100, -500, 1),
        (100, -100, 1),
        (100, -99, 1),
        (100, -50, 50),
        (100, 0, 100),
        (100, 125, 225),
        (1, -1, 1)
    ])
    func keepsPricesPositiveWithoutChangingValidMovements(
        scenario: (priceInCents: Int, movementInCents: Int, expectedPriceInCents: Int)
    ) {
        var stock = Stock(
            symbol: "AAPL",
            name: "Apple",
            description: "Test stock",
            currencyCode: "USD",
            price: Decimal(scenario.priceInCents) / 100,
            change: 0
        )
        let originalPrice = stock.price

        let update = PriceSimulator.makeUpdate(
            for: stock,
            movementInCents: scenario.movementInCents
        )

        #expect(update.symbol == stock.symbol)
        #expect(update.price == Decimal(scenario.expectedPriceInCents) / 100)

        stock.applyPrice(update.price)
        #expect(stock.change == update.price - originalPrice)
    }
}
