//
//  LiveStockRepositoryTests.swift
//  StockPriceTrackerTests
//
//  Created by Abhishek on 02/11/2026.
//

import Foundation
import Testing
import WebSocketTransport
@testable import StockPriceTracker

@MainActor
struct LiveStockRepositoryTests {
    @Test
    func appliesEchoedPriceInsteadOfOutgoingPrice() async throws {
        let client = StubWebSocketClient(
            response: .text(
                #"{"symbol":"AAPL","price":103}"#
            )
        )

        let endpoint = try #require(
            URL(string: "wss://example.com")
        )

        let repository = LiveStockRepository(
            client: client,
            endpoint: endpoint,
            stocks: [
                Stock(
                    symbol: "AAPL",
                    name: "Apple",
                    description: "Test stock",
                    currencyCode: "USD",
                    price: 100,
                    change: 0
                )
            ],
            makeUpdate: { _ in
                StockPriceMessage(
                    symbol: "AAPL",
                    price: 105
                )
            }
        )

        try await repository.connect()

        let stocks = try await repository.nextUpdate()
        let stock = try #require(stocks.first)

        // The outgoing message proposed 105; the echo supplied 103.
        #expect(stock.price == 103)
        #expect(stock.change == 3)

        let sent = await client.lastSent
        let message = try #require(sent)

        switch message {
        case .text(let text):
            let payload = try JSONDecoder().decode(
                StockPriceMessage.self,
                from: Data(text.utf8)
            )

            #expect(payload.symbol == "AAPL")
            #expect(payload.price == 105)
        }

        await repository.disconnect()
    }
}

private actor StubWebSocketClient: WebSocketClient {
    private let response: WebSocketMessage
    private(set) var lastSent: WebSocketMessage?

    init(response: WebSocketMessage) {
        self.response = response
    }

    func connect(to url: URL) async throws {}

    func send(_ message: WebSocketMessage) async throws {
        lastSent = message
    }

    func receive() async throws -> WebSocketMessage {
        response
    }

    func disconnect() async {}
}
