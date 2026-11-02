import Foundation
import Observation
import Testing
@testable import StockPriceTracker

@MainActor
struct StockTrackingRecoveryTests {
    @Test
    func connectionFailureCleansUpAndAllowsSuccessfulRetry() async {
        let repository = RetryStockRepository()
        let service = StockTrackingService(repository: repository)
        let originalStocks = service.stocks

        service.start()
        await waitForStateChange(in: service)

        #expect(service.state == .failed)
        #expect(repository.connectCount == 1)
        #expect(repository.disconnectCount == 1)
        #expect(service.stocks == originalStocks)

        service.start()
        #expect(service.state == .connecting)
        await waitForStateChange(in: service)

        #expect(service.state == .connected)
        #expect(repository.connectCount == 2)
        #expect(service.stocks == originalStocks)

        await service.stop()

        #expect(service.state == .disconnected)
        #expect(repository.disconnectCount == 2)
    }

    private func waitForStateChange(in service: StockTrackingService) async {
        await withCheckedContinuation { continuation in
            withObservationTracking {
                _ = service.state
            } onChange: {
                // Observation fires before assignment. Resume on the main actor
                // after the service finishes updating its state and task handle.
                Task { @MainActor in
                    continuation.resume()
                }
            }
        }
    }
}

@MainActor
private final class RetryStockRepository: StockRepository {
    let stocks = [
        Stock(
            symbol: "AAPL",
            name: "Apple",
            description: "Test stock",
            currencyCode: "USD",
            price: 100,
            change: 2
        )
    ]
    private(set) var connectCount = 0
    private(set) var disconnectCount = 0

    func connect() async throws {
        connectCount += 1
        if connectCount == 1 {
            throw ConnectionFailure.unavailable
        }
    }

    func nextUpdate() async throws -> [Stock] {
        stocks
    }

    func disconnect() async {
        disconnectCount += 1
    }

    private enum ConnectionFailure: Error {
        case unavailable
    }
}
