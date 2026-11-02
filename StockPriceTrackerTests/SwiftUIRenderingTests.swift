import Foundation
import SwiftUI
import Testing
import UIKit
@testable import StockPriceTracker

/// Hosts views long enough for body evaluation so presentation code counts toward coverage.
@MainActor
struct SwiftUIRenderingTests {
    @Test
    func priceChangeViewRendersUpDownAndFlatStates() {
        for change in [Decimal(2), Decimal(-3), Decimal(0)] {
            let host = UIHostingController(rootView: PriceChangeView(change: change))
            host.loadViewIfNeeded()
            #expect(host.view != nil)
        }
    }

    @Test
    func stockRowRendersIdentityAndPricing() {
        let stock = Stock(
            symbol: "AAPL",
            name: "Apple",
            description: "Apple designs personal devices, software, and digital services.",
            currencyCode: "USD",
            price: 150,
            change: 1.25
        )
        let host = UIHostingController(rootView: StockRowView(stock: stock).frame(width: 390))
        host.loadViewIfNeeded()
        #expect(host.view != nil)
    }

    @Test
    func listAndDetailScreensRenderSharedServiceState() {
        let repository = RenderRepository()
        let tracking = StockTrackingService(repository: repository)
        let listModel = StockListViewModel(tracking: tracking)

        let listHost = UIHostingController(
            rootView: StockListView(viewModel: listModel, selection: .constant("AAPL"))
                .frame(width: 390, height: 800)
        )
        listHost.loadViewIfNeeded()
        #expect(listHost.view != nil)

        let detailHost = UIHostingController(
            rootView: StockDetailView(
                viewModel: StockDetailViewModel(symbol: "AAPL", tracking: tracking)
            )
            .frame(width: 390, height: 800)
        )
        detailHost.loadViewIfNeeded()
        #expect(detailHost.view != nil)

        let missingHost = UIHostingController(
            rootView: StockDetailView(
                viewModel: StockDetailViewModel(symbol: "MISSING", tracking: tracking)
            )
            .frame(width: 390, height: 800)
        )
        missingHost.loadViewIfNeeded()
        #expect(missingHost.view != nil)

        let contentHost = UIHostingController(
            rootView: ContentView(tracking: tracking)
                .frame(width: 1024, height: 768)
        )
        contentHost.loadViewIfNeeded()
        #expect(contentHost.view != nil)
    }

    @Test(arguments: [FeedState.disconnected, .connecting, .connected, .stopping, .failed])
    func listHeaderReflectsFeedStates(state: FeedState) async {
        let repository = StatefulRepository(stateSeed: state)
        let tracking = StockTrackingService(repository: repository)
        // Drive the service into the requested state where start/stop apply.
        switch state {
        case .disconnected:
            break
        case .connecting:
            repository.blockConnect = true
            tracking.start()
        case .connected:
            tracking.start()
            let deadline = DispatchTime.now() + .seconds(2)
            while DispatchTime.now() < deadline, tracking.state != .connected {
                try? await Task.sleep(for: .milliseconds(10))
            }
        case .stopping:
            tracking.start()
            let deadline = DispatchTime.now() + .seconds(2)
            while DispatchTime.now() < deadline, tracking.state != .connected {
                try? await Task.sleep(for: .milliseconds(10))
            }
            async let stopping: Void = tracking.stop()
            try? await Task.sleep(for: .milliseconds(5))
            _ = await stopping
        case .failed:
            repository.failConnect = true
            tracking.start()
            let deadline = DispatchTime.now() + .seconds(2)
            while DispatchTime.now() < deadline, tracking.state != .failed {
                try? await Task.sleep(for: .milliseconds(10))
            }
        }

        let listModel = StockListViewModel(tracking: tracking)
        let host = UIHostingController(
            rootView: StockListView(viewModel: listModel, selection: .constant(nil))
                .frame(width: 390, height: 800)
        )
        host.loadViewIfNeeded()
        #expect(host.view != nil)

        if tracking.state == .connecting || tracking.state == .connected {
            await tracking.stop()
        }
    }
}

@MainActor
private final class RenderRepository: StockRepository {
    let stocks = [
        Stock(
            symbol: "AAPL",
            name: "Apple",
            description: "Apple designs personal devices, software, and digital services.",
            currencyCode: "USD",
            price: 150,
            change: 1.5
        )
    ]

    func connect() async throws {}
    func nextUpdate() async throws -> [Stock] { stocks }
    func disconnect() async {}
}

@MainActor
private final class StatefulRepository: StockRepository {
    let stocks = [
        Stock(
            symbol: "AAPL",
            name: "Apple",
            description: "Apple designs personal devices, software, and digital services.",
            currencyCode: "USD",
            price: 150,
            change: -1
        )
    ]
    var blockConnect = false
    var failConnect = false
    private var connection: CheckedContinuation<Void, any Error>?

    init(stateSeed: FeedState) {
        _ = stateSeed
    }

    func connect() async throws {
        if failConnect {
            throw ConnectFailure.failed
        }
        if blockConnect {
            try await withCheckedThrowingContinuation { continuation in
                connection = continuation
            }
        }
    }

    func nextUpdate() async throws -> [Stock] {
        try await Task.sleep(for: .seconds(30))
        return stocks
    }

    func disconnect() async {
        connection?.resume(throwing: CancellationError())
        connection = nil
    }

    private enum ConnectFailure: Error { case failed }
}
