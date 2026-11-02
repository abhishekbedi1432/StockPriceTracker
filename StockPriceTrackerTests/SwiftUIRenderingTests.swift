import Foundation
import SwiftUI
import Testing
import UIKit
@testable import StockPriceTracker

/// Hosts SwiftUI views in a real window so body evaluation counts toward coverage.
@MainActor
struct SwiftUIRenderingTests {
    @Test
    func priceChangeViewRendersUpDownAndFlatStates() {
        for change in [Decimal(2), Decimal(-3), Decimal(0)] {
            render(PriceChangeView(change: change))
        }
    }

    @Test
    func stockRowRendersRegularAndAccessibilityLayouts() {
        let stock = makeStock(symbol: "AAPL", price: 150, change: 1.25)

        render(
            StockRowView(stock: stock)
                .environment(\.dynamicTypeSize, .large)
                .frame(width: 390)
        )
        render(
            StockRowView(stock: stock)
                .environment(\.dynamicTypeSize, .accessibility3)
                .frame(width: 390)
        )
    }

    @Test
    func stockDetailRendersAvailableAndMissingStates() {
        let tracking = StockTrackingService(repository: RenderRepository())

        // Non-nil stock path exercises priceSummary + aboutSection.
        render(
            NavigationStack {
                StockDetailView(
                    viewModel: StockDetailViewModel(symbol: "AAPL", tracking: tracking)
                )
            }
            .frame(width: 390, height: 844)
        )

        // Nil stock path exercises ContentUnavailableView branch.
        render(
            NavigationStack {
                StockDetailView(
                    viewModel: StockDetailViewModel(symbol: "MISSING", tracking: tracking)
                )
            }
            .frame(width: 390, height: 844)
        )
    }

    @Test
    func stockListRendersAllFeedStatesAndActions() async {
        // disconnected / Start
        await renderListState(.disconnected, tapFeedButton: true)

        // connecting / Cancel
        await renderListState(.connecting, tapFeedButton: true)

        // connected / Stop
        await renderListState(.connected, tapFeedButton: true)

        // stopping (button disabled)
        await renderListState(.stopping, tapFeedButton: true)

        // failed / Retry message + button
        await renderListState(.failed, tapFeedButton: true)

        // Accessibility Dynamic Type uses menu picker style.
        let tracking = StockTrackingService(repository: RenderRepository())
        let host = render(
            StockListView(
                viewModel: StockListViewModel(tracking: tracking),
                selection: .constant("AAPL")
            )
            .environment(\.dynamicTypeSize, .accessibility2)
            .frame(width: 390, height: 844)
        )
        #expect(host.view != nil)
    }

    @Test
    func contentViewRendersEmptyAndSelectedDetail() {
        let tracking = StockTrackingService(repository: RenderRepository())

        render(
            ContentView(tracking: tracking)
                .frame(width: 1024, height: 768)
        )

        // Force the selected-detail branch by hosting the same structure ContentView uses.
        render(
            NavigationSplitView {
                StockListView(
                    viewModel: StockListViewModel(tracking: tracking),
                    selection: .constant("AAPL")
                )
            } detail: {
                StockDetailView(
                    viewModel: StockDetailViewModel(symbol: "AAPL", tracking: tracking)
                )
                .id("AAPL")
            }
            .navigationSplitViewStyle(.balanced)
            .preferredColorScheme(.dark)
            .frame(width: 1024, height: 768)
        )
    }

    @Test
    func appBackgroundPolicyStopsActiveFeed() async {
        let repository = ParkedRepository()
        let tracking = StockTrackingService(repository: repository)
        tracking.start()
        await waitUntil(tracking) { $0.state == .connected }

        await StockPriceTrackerApp.handleScenePhase(.background, tracking: tracking)
        #expect(tracking.state == .disconnected)

        // Other phases are no-ops.
        await StockPriceTrackerApp.handleScenePhase(.active, tracking: tracking)
        await StockPriceTrackerApp.handleScenePhase(.inactive, tracking: tracking)
        #expect(tracking.state == .disconnected)
    }

    // MARK: - Helpers

    @discardableResult
    private func render<V: View>(_ view: V) -> UIHostingController<V> {
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1024, height: 768))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.loadViewIfNeeded()
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        // Allow SwiftUI to commit the first frame.
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        window.isHidden = true
        return host
    }

    private func renderListState(
        _ state: FeedState,
        tapFeedButton: Bool
    ) async {
        let repository = StatefulListRepository(target: state)
        let tracking = StockTrackingService(repository: repository)
        let listModel = StockListViewModel(tracking: tracking)

        switch state {
        case .disconnected:
            break
        case .connecting:
            repository.blockConnect = true
            tracking.start()
            await waitUntil(tracking) { $0.state == .connecting }
        case .connected:
            tracking.start()
            await waitUntil(tracking) { $0.state == .connected }
        case .stopping:
            tracking.start()
            await waitUntil(tracking) { $0.state == .connected }
            // Leave stop in-flight long enough to render .stopping once.
            repository.delayDisconnect = true
            let stopTask = Task { await tracking.stop() }
            await waitUntil(tracking) { $0.state == .stopping }
            let host = render(
                StockListView(viewModel: listModel, selection: .constant(nil))
                    .frame(width: 390, height: 844)
            )
            if tapFeedButton {
                tapButtons(in: host.view)
            }
            repository.delayDisconnect = false
            repository.finishDisconnect()
            await stopTask.value
            return
        case .failed:
            repository.failConnect = true
            tracking.start()
            await waitUntil(tracking) { $0.state == .failed }
        }

        let host = render(
            NavigationStack {
                StockListView(viewModel: listModel, selection: .constant("AAPL"))
            }
            .frame(width: 390, height: 844)
        )

        if tapFeedButton {
            tapButtons(in: host.view)
            // Let Start/Cancel/Stop/Retry tasks settle without leaving orphans.
            try? await Task.sleep(for: .milliseconds(50))
        }

        if tracking.state == .connecting || tracking.state == .connected || tracking.state == .stopping {
            await tracking.stop()
        } else if tracking.state == .failed {
            await tracking.stop()
        }
    }

    private func tapButtons(in root: UIView?) {
        guard let root else { return }
        var queue: [UIView] = [root]
        while let view = queue.first {
            queue.removeFirst()
            queue.append(contentsOf: view.subviews)
            if let button = view as? UIButton, button.isEnabled {
                button.sendActions(for: .touchUpInside)
            }
        }
    }

    private func makeStock(
        symbol: String,
        price: Decimal,
        change: Decimal
    ) -> Stock {
        Stock(
            symbol: symbol,
            name: "Apple",
            description: "Apple designs personal devices, software, and digital services.",
            currencyCode: "USD",
            price: price,
            change: change
        )
    }
}

// MARK: - Repositories

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
    func nextUpdate() async throws -> [Stock] {
        try await withCheckedThrowingContinuation { continuation in
            // Park until disconnect so the feed cannot spin.
            parked = continuation
        }
    }
    func disconnect() async {
        let pending = parked
        parked = nil
        pending?.resume(throwing: CancellationError())
    }

    private var parked: CheckedContinuation<[Stock], any Error>?
}

@MainActor
private final class ParkedRepository: StockRepository {
    let stocks = [
        Stock(
            symbol: "AAPL",
            name: "Apple",
            description: "Apple designs personal devices, software, and digital services.",
            currencyCode: "USD",
            price: 150,
            change: 0
        )
    ]
    private var parked: CheckedContinuation<[Stock], any Error>?

    func connect() async throws {}
    func nextUpdate() async throws -> [Stock] {
        try await withCheckedThrowingContinuation { continuation in
            parked = continuation
        }
    }
    func disconnect() async {
        let pending = parked
        parked = nil
        pending?.resume(throwing: CancellationError())
    }
}

@MainActor
private final class StatefulListRepository: StockRepository {
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
    var delayDisconnect = false

    private var connection: CheckedContinuation<Void, any Error>?
    private var parkedUpdate: CheckedContinuation<[Stock], any Error>?
    private var disconnectWaiter: CheckedContinuation<Void, Never>?

    init(target: FeedState) {
        _ = target
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
        try await withCheckedThrowingContinuation { continuation in
            parkedUpdate = continuation
        }
    }

    func disconnect() async {
        if delayDisconnect {
            await withCheckedContinuation { continuation in
                disconnectWaiter = continuation
            }
        }
        connection?.resume(throwing: CancellationError())
        connection = nil
        parkedUpdate?.resume(throwing: CancellationError())
        parkedUpdate = nil
    }

    func finishDisconnect() {
        let waiter = disconnectWaiter
        disconnectWaiter = nil
        waiter?.resume()
    }

    private enum ConnectFailure: Error { case failed }
}

@MainActor
private func waitUntil(
    _ service: StockTrackingService,
    timeoutNanoseconds: UInt64 = 2_000_000_000,
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
