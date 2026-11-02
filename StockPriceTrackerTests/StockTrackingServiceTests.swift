import Foundation
import Testing
@testable import StockPriceTracker

@MainActor
struct StockTrackingServiceTests {
    @Test
    func repeatedStartCreatesOnlyOneConnection() async {
        let repository = ConnectingStockRepository()
        let service = StockTrackingService(repository: repository)

        service.start()
        service.start()
        await repository.waitForConnection()
        service.start()
        await service.stop()

        #expect(repository.connectCount == 1)
        #expect(repository.disconnectCount == 1)
        #expect(repository.updateCount == 0)
        #expect(service.state == .disconnected)
    }

    @Test
    func stoppingDuringConnectionPreservesPricesAndDoesNotFail() async {
        let repository = ConnectingStockRepository()
        let service = StockTrackingService(repository: repository)
        let originalStocks = service.stocks

        service.start()
        await repository.waitForConnection()
        #expect(service.state == .connecting)

        await service.stop()

        #expect(service.state == .disconnected)
        #expect(service.stocks == originalStocks)
        #expect(repository.updateCount == 0)
        #expect(repository.disconnectCount == 1)
    }

    @Test
    func immediateStopAndRepeatedStopAreSafe() async {
        let repository = ConnectingStockRepository()
        let service = StockTrackingService(repository: repository)

        await service.stop()
        #expect(repository.disconnectCount == 0)

        service.start()
        await service.stop()
        await service.stop()

        #expect(service.state == .disconnected)
        #expect(repository.disconnectCount == 1)
        #expect(repository.updateCount == 0)
    }

    @Test
    func canStartAgainAfterStoppingDuringConnection() async {
        let repository = ConnectingStockRepository()
        let service = StockTrackingService(repository: repository)

        service.start()
        await repository.waitForConnection()
        await service.stop()

        service.start()
        await repository.waitForConnection()
        #expect(service.state == .connecting)
        #expect(repository.connectCount == 2)

        await service.stop()

        #expect(service.state == .disconnected)
        #expect(repository.disconnectCount == 2)
        #expect(repository.updateCount == 0)
    }
}

/// Holds connection completion until disconnect, without network calls or sleeps.
@MainActor
private final class ConnectingStockRepository: StockRepository {
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
    private(set) var updateCount = 0

    private var connection: CheckedContinuation<Void, any Error>?
    private var connectionStarted: CheckedContinuation<Void, Never>?

    func connect() async throws {
        // A stop may cancel the service task before it first reaches connect.
        try Task.checkCancellation()
        connectCount += 1
        try await withCheckedThrowingContinuation { continuation in
            connection = continuation
            connectionStarted?.resume()
            connectionStarted = nil
        }
    }

    func waitForConnection() async {
        if connection != nil { return }
        await withCheckedContinuation { continuation in
            connectionStarted = continuation
        }
    }

    func nextUpdate() async throws -> [Stock] {
        updateCount += 1
        Issue.record("The service requested an update before connection completed.")
        return stocks
    }

    func disconnect() async {
        disconnectCount += 1
        let pendingConnection = connection
        connection = nil
        // Model a transport that completes its pending connection as it closes.
        // The service must still honor cancellation before publishing connected.
        pendingConnection?.resume()
    }
}
