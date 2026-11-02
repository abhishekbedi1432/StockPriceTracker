import Foundation
import SwiftUI
import Testing
import UIKit
import WebSocketTransport
@testable import StockPriceTracker

// MARK: - ContentView

@MainActor
struct ContentViewCoverageTests {
    @Test
    func rendersEmptyDetailAndSelectedDetailBranches() {
        let tracking = StockTrackingService(repository: IdleRepository())

        render(ContentView(tracking: tracking).frame(width: 1024, height: 768))
        render(
            ContentView(tracking: tracking, selectedSymbol: "AAPL")
                .frame(width: 1024, height: 768)
        )
    }
}

// MARK: - StockListView

@MainActor
struct StockListViewCoverageTests {
    @Test
    func rendersAllFeedStatesAndDynamicTypeVariants() async {
        for state in [FeedState.disconnected, .connecting, .connected, .stopping, .failed] {
            await renderList(state: state, dynamicType: .large)
            await renderList(state: state, dynamicType: .accessibility3)
        }
    }

    @Test
    func handleFeedActionCoversAllBranches() async {
        // disconnected -> start
        do {
            let h = harness(blockConnect: true)
            h.list.handleFeedAction()
            #expect(h.tracking.state == .connecting)
            await h.tracking.stop()
            #expect(h.tracking.state == .disconnected)
        }

        // failed -> retry/start
        do {
            let h = harness(failConnect: true)
            h.tracking.start()
            await waitUntil(h.tracking) { $0.state == .failed }
            h.list.handleFeedAction()
            await waitUntil(h.tracking) { $0.state == .connecting || $0.state == .failed }
            await h.tracking.stop()
            #expect(h.tracking.state == .disconnected)
        }

        // connecting -> cancel/stop (await completion; do not overlap stops)
        do {
            let h = harness(blockConnect: true)
            h.tracking.start()
            await waitUntil(h.tracking) { $0.state == .connecting }
            h.list.handleFeedAction()
            await waitUntil(h.tracking) { $0.state == .disconnected }
        }

        // connected -> stop
        do {
            let h = harness()
            h.tracking.start()
            await waitUntil(h.tracking) { $0.state == .connected }
            h.list.handleFeedAction()
            await waitUntil(h.tracking) { $0.state == .disconnected }
        }

        // stopping -> no-op
        do {
            let h = harness()
            h.tracking.start()
            await waitUntil(h.tracking) { $0.state == .connected }

            h.repository.holdDisconnect = true
            let stopTask = Task { await h.tracking.stop() }
            await waitUntil(h.tracking) { $0.state == .stopping }

            h.list.handleFeedAction()
            #expect(h.tracking.state == .stopping)

            h.repository.releaseDisconnect()
            await stopTask.value
            #expect(h.tracking.state == .disconnected)
        }
    }

    private func renderList(state: FeedState, dynamicType: DynamicTypeSize) async {
        let h = harness(
            blockConnect: state == .connecting,
            failConnect: state == .failed
        )

        switch state {
        case .disconnected:
            break
        case .connecting:
            h.tracking.start()
            await waitUntil(h.tracking) { $0.state == .connecting }
        case .connected:
            h.tracking.start()
            await waitUntil(h.tracking) { $0.state == .connected }
        case .stopping:
            h.tracking.start()
            await waitUntil(h.tracking) { $0.state == .connected }
            h.repository.holdDisconnect = true
            let stopTask = Task { await h.tracking.stop() }
            await waitUntil(h.tracking) { $0.state == .stopping }
            render(
                NavigationStack {
                    h.list.environment(\.dynamicTypeSize, dynamicType)
                }
                .frame(width: 390, height: 844)
            )
            h.repository.releaseDisconnect()
            await stopTask.value
            return
        case .failed:
            h.tracking.start()
            await waitUntil(h.tracking) { $0.state == .failed }
        }

        render(
            NavigationStack {
                h.list.environment(\.dynamicTypeSize, dynamicType)
            }
            .frame(width: 390, height: 844)
        )

        // Always stop via the service API (never fire-and-forget) so the feed
        // task cannot outlive the test.
        await h.tracking.stop()
    }

    private func harness(
        blockConnect: Bool = false,
        failConnect: Bool = false
    ) -> (repository: ControllableRepository, tracking: StockTrackingService, list: StockListView) {
        let repository = ControllableRepository()
        repository.blockConnect = blockConnect
        repository.failConnect = failConnect
        let tracking = StockTrackingService(repository: repository)
        let list = StockListView(
            viewModel: StockListViewModel(tracking: tracking),
            selection: .constant("AAPL")
        )
        return (repository, tracking, list)
    }
}

// MARK: - LiveStockRepository

@MainActor
struct LiveStockRepositoryCoverageTests {
    @Test
    func defaultMakeUpdatesEchoesAppliedBatch() async throws {
        let client = EchoClient()
        let endpoint = try #require(URL(string: "wss://example.com"))
        let repository = LiveStockRepository(
            client: client,
            endpoint: endpoint,
            stocks: [
                Stock(symbol: "AAPL", name: "A", description: "T", currencyCode: "USD", price: 100, change: 0),
                Stock(symbol: "MSFT", name: "M", description: "T", currencyCode: "USD", price: 200, change: 0),
                Stock(symbol: "GOOG", name: "G", description: "T", currencyCode: "USD", price: 300, change: 0)
            ]
        )

        try await repository.connect()
        let updated = try await repository.nextUpdate()
        #expect(updated.count == 3)
        await repository.disconnect()
    }

    @Test
    func cancellationAfterReceiveDoesNotApplyPrices() async throws {
        let client = GateClient(response: .text(#"[{"symbol":"AAPL","price":999}]"#))
        let endpoint = try #require(URL(string: "wss://example.com"))
        let repository = LiveStockRepository(
            client: client,
            endpoint: endpoint,
            stocks: [
                Stock(symbol: "AAPL", name: "A", description: "T", currencyCode: "USD", price: 100, change: 0)
            ],
            makeUpdates: { _ in [StockPriceMessage(symbol: "AAPL", price: 105)] }
        )

        try await repository.connect()
        let original = repository.stocks

        let task = Task { @MainActor in
            try await repository.nextUpdate()
        }
        await client.waitForReceiveEntry()
        task.cancel()
        await client.allowReceiveToFinish()

        do {
            _ = try await task.value
            Issue.record("Expected cancellation.")
        } catch is CancellationError {
            // expected
        } catch {
            // Task may surface CancellationError wrapped; prices must stay put either way.
        }
        #expect(repository.stocks == original)
        await repository.disconnect()
    }

    @Test
    func emptyEchoBatchLeavesPricesUnchanged() async throws {
        let client = FixedClient(response: .text("[]"))
        let endpoint = try #require(URL(string: "wss://example.com"))
        let repository = LiveStockRepository(
            client: client,
            endpoint: endpoint,
            stocks: [
                Stock(symbol: "AAPL", name: "A", description: "T", currencyCode: "USD", price: 100, change: 4)
            ],
            makeUpdates: { _ in [StockPriceMessage(symbol: "AAPL", price: 105)] }
        )
        try await repository.connect()
        let stocks = try await repository.nextUpdate()
        #expect(stocks[0].price == 100)
        #expect(stocks[0].change == 4)
        await repository.disconnect()
    }
}

// MARK: - StockTrackingService

@MainActor
struct StockTrackingServiceCoverageTests {
    @Test
    func startIsIgnoredWhileStopping() async {
        let repository = ControllableRepository()
        let service = StockTrackingService(repository: repository)
        service.start()
        await waitUntil(service) { $0.state == .connected }

        repository.holdDisconnect = true
        let stopTask = Task { await service.stop() }
        await waitUntil(service) { $0.state == .stopping }

        service.start()
        #expect(service.state == .stopping)
        #expect(repository.connectCount == 1)

        repository.releaseDisconnect()
        await stopTask.value
        #expect(service.state == .disconnected)
    }

    @Test
    func sequentialStopsAreSafe() async {
        let repository = ControllableRepository()
        let service = StockTrackingService(repository: repository)
        service.start()
        await waitUntil(service) { $0.state == .connected }

        await service.stop()
        await service.stop()

        #expect(service.state == .disconnected)
        #expect(repository.disconnectCount == 1)
    }

    @Test
    func stopWhileFailedClearsState() async {
        let repository = ControllableRepository()
        repository.failConnect = true
        let service = StockTrackingService(repository: repository)

        service.start()
        await waitUntil(service) { $0.state == .failed }
        await service.stop()
        #expect(service.state == .disconnected)
    }

    @Test
    func publishesUpdatesUntilStopped() async {
        let repository = OneShotUpdateRepository()
        let service = StockTrackingService(repository: repository)

        service.start()
        await waitUntil(service) { $0.state == .connected && $0.stocks[0].price == 150 }
        #expect(service.stocks[0].price == 150)
        await service.stop()
        #expect(service.state == .disconnected)
    }
}

// MARK: - Repositories / clients

@MainActor
private final class IdleRepository: StockRepository {
    let stocks = [
        Stock(symbol: "AAPL", name: "Apple", description: "T", currencyCode: "USD", price: 150, change: 1)
    ]
    func connect() async throws {}
    func nextUpdate() async throws -> [Stock] { stocks }
    func disconnect() async {}
}

@MainActor
private final class ControllableRepository: StockRepository {
    let stocks = [
        Stock(symbol: "AAPL", name: "Apple", description: "T", currencyCode: "USD", price: 150, change: -1)
    ]
    var blockConnect = false
    var failConnect = false
    var holdDisconnect = false
    private(set) var connectCount = 0
    private(set) var disconnectCount = 0

    private let connectGate = ParkGate<Void>()
    private let updateGate = ParkGate<[Stock]>()
    private var heldDisconnect: CheckedContinuation<Void, Never>?

    func connect() async throws {
        connectCount += 1
        if failConnect { throw Failure.boom }
        if blockConnect {
            try await connectGate.park()
        }
    }

    func nextUpdate() async throws -> [Stock] {
        try await updateGate.park()
    }

    func disconnect() async {
        disconnectCount += 1
        // Cancel gates first: a feed task that arrives late must not strand a continuation.
        connectGate.cancel()
        updateGate.cancel()

        if holdDisconnect {
            await withCheckedContinuation { continuation in
                heldDisconnect = continuation
            }
        }
    }

    func releaseDisconnect() {
        holdDisconnect = false
        let held = heldDisconnect
        heldDisconnect = nil
        held?.resume()
    }

    private enum Failure: Error { case boom }
}

@MainActor
private final class OneShotUpdateRepository: StockRepository {
    private(set) var stocks = [
        Stock(symbol: "AAPL", name: "Apple", description: "T", currencyCode: "USD", price: 100, change: 0)
    ]
    private var updates = 0
    private let gate = ParkGate<[Stock]>()

    func connect() async throws {}

    func nextUpdate() async throws -> [Stock] {
        updates += 1
        if updates == 1 {
            stocks[0].applyPrice(150)
            return stocks
        }
        return try await gate.park()
    }

    func disconnect() async {
        gate.cancel()
    }
}

private actor FixedClient: WebSocketClient {
    private let response: WebSocketMessage
    init(response: WebSocketMessage) { self.response = response }
    func connect(to url: URL) async throws {}
    func send(_ message: WebSocketMessage) async throws {}
    func receive() async throws -> WebSocketMessage { response }
    func disconnect() async {}
}

private actor EchoClient: WebSocketClient {
    private var lastText: String?
    func connect(to url: URL) async throws {}
    func send(_ message: WebSocketMessage) async throws {
        if case .text(let text) = message { lastText = text }
    }
    func receive() async throws -> WebSocketMessage { .text(lastText ?? "[]") }
    func disconnect() async {}
}

private actor GateClient: WebSocketClient {
    private let response: WebSocketMessage
    private var entered: CheckedContinuation<Void, Never>?
    private var release: CheckedContinuation<Void, Never>?

    init(response: WebSocketMessage) { self.response = response }

    func connect(to url: URL) async throws {}
    func send(_ message: WebSocketMessage) async throws {}

    func receive() async throws -> WebSocketMessage {
        entered?.resume()
        entered = nil
        await withCheckedContinuation { continuation in
            release = continuation
        }
        return response
    }

    func waitForReceiveEntry() async {
        if release != nil { return }
        await withCheckedContinuation { continuation in
            entered = continuation
        }
    }

    func allowReceiveToFinish() {
        let pending = release
        release = nil
        pending?.resume()
    }

    func disconnect() async {}
}

// MARK: - UI helpers

@MainActor
@discardableResult
private func render<V: View>(_ view: V) -> UIHostingController<V> {
    let host = UIHostingController(rootView: view)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1024, height: 768))
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.loadViewIfNeeded()
    host.view.frame = window.bounds
    host.view.layoutIfNeeded()
    RunLoop.current.run(until: Date().addingTimeInterval(0.02))
    window.isHidden = true
    return host
}

@MainActor
private func waitUntil(
    _ service: StockTrackingService,
    timeoutNanoseconds: UInt64 = 3_000_000_000,
    condition: @MainActor (StockTrackingService) -> Bool
) async {
    let deadline = DispatchTime.now() + .nanoseconds(Int(timeoutNanoseconds))
    while DispatchTime.now() < deadline {
        if condition(service) { return }
        try? await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Timed out waiting for service condition. state=\(service.state)")
}
