//
//  StockPriceTrackerApp.swift
//  StockPriceTracker
//
//  Created by Abhishek on 02/11/2026.
//

import SwiftUI
import WebSocketTransport

@main
@MainActor
struct StockPriceTrackerApp: App {
    @State private var tracking: StockTrackingService
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let repository = LiveStockRepository(
            client: URLSessionWebSocketClient(),
            endpoint: URL(
                string: "wss://ws.postman-echo.com/raw"
            )!,
            stocks: PriceSimulator.makeInitialStocks(
                currencyCode: "USD"
            )
        )

        _tracking = State(
            initialValue: StockTrackingService(
                repository: repository
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(tracking: tracking)
                .onChange(of: scenePhase) { _, phase in
                    Task {
                        await Self.handleScenePhase(phase, tracking: tracking)
                    }
                }
        }
    }

    /// Stops the feed when the app leaves the foreground so prices freeze until Start.
    static func handleScenePhase(
        _ phase: ScenePhase,
        tracking: StockTrackingService
    ) async {
        guard phase == .background else { return }
        await tracking.stop()
    }
}
