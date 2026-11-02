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
                    if phase == .background {
                        // Preserve prices, but require Start after returning.
                        Task { await tracking.stop() }
                    }
                }
        }
    }
}
