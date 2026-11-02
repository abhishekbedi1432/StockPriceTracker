import Foundation
import Testing
@testable import StockPriceTracker

@MainActor
struct ViewModelCoverageTests {
    @Test
    func detailViewModelReturnsNilForUnknownSymbol() {
        let repository = StaticRepository()
        let tracking = StockTrackingService(repository: repository)
        let detail = StockDetailViewModel(symbol: "MISSING", tracking: tracking)

        #expect(detail.stock == nil)
        #expect(detail.symbol == "MISSING")
    }

    @Test
    func detailViewModelTracksSharedSymbol() {
        let repository = StaticRepository()
        let tracking = StockTrackingService(repository: repository)
        let detail = StockDetailViewModel(symbol: "AAPL", tracking: tracking)

        #expect(detail.stock?.price == 100)
        #expect(detail.stock?.symbol == "AAPL")
    }

    @Test
    func listViewModelExposesSharedStateAndControls() async {
        let repository = StaticRepository()
        let tracking = StockTrackingService(repository: repository)
        let list = StockListViewModel(tracking: tracking)

        #expect(list.state == .disconnected)
        #expect(list.stocks.map(\.symbol) == ["MSFT", "AAPL"])

        list.sortOption = .change
        #expect(list.stocks.map(\.symbol) == ["AAPL", "MSFT"])

        list.start()
        #expect(list.state == .connecting || list.state == .connected)
        await list.stop()
        #expect(list.state == .disconnected)
    }

    @Test
    func stopClearsFailedStateWithoutActiveTask() async {
        let repository = ImmediateFailureRepository()
        let service = StockTrackingService(repository: repository)

        service.start()
        let deadline = DispatchTime.now() + .seconds(2)
        while DispatchTime.now() < deadline, service.state != .failed {
            try? await Task.sleep(for: .milliseconds(10))
        }

        #expect(service.state == .failed)
        await service.stop()
        #expect(service.state == .disconnected)
    }
}

@MainActor
private final class StaticRepository: StockRepository {
    let stocks = [
        Stock(symbol: "AAPL", name: "Apple", description: "A", currencyCode: "USD", price: 100, change: 5),
        Stock(symbol: "MSFT", name: "Microsoft", description: "M", currencyCode: "USD", price: 200, change: 1)
    ]

    func connect() async throws {}
    func nextUpdate() async throws -> [Stock] { stocks }
    func disconnect() async {}
}

@MainActor
private final class ImmediateFailureRepository: StockRepository {
    let stocks = [
        Stock(symbol: "AAPL", name: "Apple", description: "A", currencyCode: "USD", price: 100, change: 0)
    ]

    func connect() async throws {
        throw Failure.boom
    }

    func nextUpdate() async throws -> [Stock] { stocks }
    func disconnect() async {}

    private enum Failure: Error { case boom }
}
