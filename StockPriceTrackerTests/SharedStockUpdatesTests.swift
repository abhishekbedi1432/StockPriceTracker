import Foundation
import Testing
@testable import StockPriceTracker

@MainActor
struct SharedStockUpdatesTests {
    @Test
    func listAndDetailShareUpdatesAndIgnoreResultsArrivingDuringStop() async {
        let repository = UpdatingStockRepository()
        let tracking = StockTrackingService(repository: repository)
        let list = StockListViewModel(tracking: tracking)
        let detail = StockDetailViewModel(symbol: "AAPL", tracking: tracking)

        #expect(list.stocks.map(\.symbol) == ["MSFT", "AAPL"])
        #expect(detail.stock?.price == 100)

        list.start()
        // The next request proves the service has published the first response.
        // Synchronize on that event instead of guessing how long to sleep.
        await repository.waitForPendingUpdate()

        #expect(list.state == .connected)
        #expect(list.stocks.map(\.symbol) == ["AAPL", "MSFT"])
        #expect(detail.stock?.price == 300)
        #expect(detail.stock?.change == 200)
        #expect(list.stocks.first(where: { $0.symbol == "AAPL" }) == detail.stock)

        await list.stop()

        // Disconnect returns a late price of 999 from the pending request.
        #expect(repository.returnedLateUpdate)
        #expect(list.state == .disconnected)
        #expect(detail.stock?.price == 300)
        #expect(detail.stock?.change == 200)
        #expect(list.stocks.first(where: { $0.symbol == "AAPL" }) == detail.stock)
    }
}

/// Returns one update, then holds the next response until the feed is stopped.
@MainActor
private final class UpdatingStockRepository: StockRepository {
    private(set) var stocks = [
        Stock(symbol: "AAPL", name: "Apple", description: "Test stock",
              currencyCode: "USD", price: 100, change: 0),
        Stock(symbol: "MSFT", name: "Microsoft", description: "Test stock",
              currencyCode: "USD", price: 200, change: 0)
    ]
    private(set) var returnedLateUpdate = false
    private var updateCount = 0
    private var pendingUpdate: CheckedContinuation<[Stock], Never>?
    private var updateRequested: CheckedContinuation<Void, Never>?

    func connect() async throws {}

    func nextUpdate() async throws -> [Stock] {
        updateCount += 1
        if updateCount == 1 {
            stocks[0].applyPrice(300)
            return stocks
        }

        return await withCheckedContinuation { continuation in
            pendingUpdate = continuation
            updateRequested?.resume()
            updateRequested = nil
        }
    }

    func waitForPendingUpdate() async {
        if pendingUpdate != nil { return }
        await withCheckedContinuation { continuation in
            updateRequested = continuation
        }
    }

    func disconnect() async {
        guard let pendingUpdate else { return }
        self.pendingUpdate = nil
        stocks[0].applyPrice(999)
        returnedLateUpdate = true
        pendingUpdate.resume(returning: stocks)
    }
}
