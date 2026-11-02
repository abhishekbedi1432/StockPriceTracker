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

    @Test
    func activeFeedFailurePreservesLastPricesAndAllowsRetry() async {
        let repository = FailingUpdateRepository()
        let service = StockTrackingService(repository: repository)

        service.start()
        await waitUntil(service) { $0.state == .connected && $0.stocks[0].price == 110 }

        #expect(service.stocks[0].price == 110)
        #expect(service.stocks[0].change == 10)

        await waitUntil(service) { $0.state == .failed }

        #expect(service.state == .failed)
        #expect(service.stocks[0].price == 110)
        #expect(repository.disconnectCount == 1)

        service.start()
        await waitUntil(service) { $0.state == .connected && $0.stocks[0].price == 120 }

        #expect(service.state == .connected)
        #expect(service.stocks[0].price == 120)
        #expect(service.stocks[0].change == 10)
        #expect(repository.connectCount == 2)

        await service.stop()
        #expect(service.state == .disconnected)
    }

    @Test
    func malformedBatchFailsServiceWithoutPublishingPartialPrices() async {
        let repository = MalformedBatchRepository()
        let service = StockTrackingService(repository: repository)
        let originalStocks = service.stocks

        service.start()
        await waitUntil(service) { $0.state == .failed }

        #expect(service.state == .failed)
        #expect(service.stocks == originalStocks)
        #expect(repository.disconnectCount == 1)

        await service.stop()
        #expect(service.state == .disconnected)
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

@MainActor
private final class FailingUpdateRepository: StockRepository {
    private(set) var stocks = [
        Stock(
            symbol: "AAPL",
            name: "Apple",
            description: "Test stock",
            currencyCode: "USD",
            price: 100,
            change: 0
        )
    ]
    private(set) var connectCount = 0
    private(set) var disconnectCount = 0
    private var updateCount = 0

    func connect() async throws {
        connectCount += 1
    }

    func nextUpdate() async throws -> [Stock] {
        updateCount += 1
        // First run: one good update, then fail. Retry run: succeed again.
        if connectCount == 1 {
            if updateCount == 1 {
                stocks[0].applyPrice(110)
                return stocks
            }
            throw UpdateFailure.transport
        }

        stocks[0].applyPrice(120)
        return stocks
    }

    func disconnect() async {
        disconnectCount += 1
    }

    private enum UpdateFailure: Error {
        case transport
    }
}

@MainActor
private final class MalformedBatchRepository: StockRepository {
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
    private(set) var disconnectCount = 0

    func connect() async throws {}

    func nextUpdate() async throws -> [Stock] {
        throw DecodingError.dataCorrupted(
            .init(codingPath: [], debugDescription: "malformed batch")
        )
    }

    func disconnect() async {
        disconnectCount += 1
    }
}

@MainActor
private func waitUntil(
    _ service: StockTrackingService,
    timeoutNanoseconds: UInt64 = 3_000_000_000,
    condition: @MainActor (StockTrackingService) -> Bool
) async {
    let deadline = DispatchTime.now() + .nanoseconds(Int(timeoutNanoseconds))
    while DispatchTime.now() < deadline {
        if condition(service) {
            return
        }
        try? await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Timed out waiting for service condition.")
}
