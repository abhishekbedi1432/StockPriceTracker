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
            ContentView()
        }
    }
}
