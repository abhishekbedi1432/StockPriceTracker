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
                #"[{"symbol":"AAPL","price":103},{"symbol":"MSFT","price":198}]"#
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
                ),
                Stock(symbol: "MSFT", name: "Microsoft", description: "Test stock",
                      currencyCode: "USD", price: 200, change: 0)
            ],
            makeUpdates: { _ in
                [
                    StockPriceMessage(symbol: "AAPL", price: 105),
                    StockPriceMessage(symbol: "MSFT", price: 205)
                ]
            }
        )

        try await repository.connect()

        let stocks = try await repository.nextUpdate()
        let stock = try #require(stocks.first)

        // The outgoing message proposed 105; the echo supplied 103.
        #expect(stock.price == 103)
        #expect(stock.change == 3)
        #expect(stocks[1].price == 198)
        #expect(stocks[1].change == -2)

        let sent = await client.lastSent
        let message = try #require(sent)

        switch message {
        case .text(let text):
            let payload = try JSONDecoder().decode(
                [StockPriceMessage].self,
                from: Data(text.utf8)
            )

            #expect(payload.map(\.symbol) == ["AAPL", "MSFT"])
            #expect(payload.map(\.price) == [105, 205])
        }

        await repository.disconnect()
    }
    @Test(arguments: [
        "not JSON",
        #"[{"symbol":"AAPL"}]"#
    ])
    func malformedResponseLeavesStocksUnchanged(response: String) async throws {
        let client = StubWebSocketClient(response: .text(response))
        let repository = try makeRepository(client: client)
        let originalStocks = repository.stocks
        try await repository.connect()

        await #expect(throws: DecodingError.self) {
            _ = try await repository.nextUpdate()
        }

        #expect(repository.stocks == originalStocks)
        await repository.disconnect()
    }

    @Test
    func unknownSymbolRejectsEntireBatch() async throws {
        // The valid update comes first to detect accidental partial application.
        let client = StubWebSocketClient(response: .text(
            #"[{"symbol":"AAPL","price":105},{"symbol":"UNKNOWN","price":200}]"#
        ))
        let repository = try makeRepository(client: client)
        let originalStocks = repository.stocks
        try await repository.connect()

        await #expect(throws: (any Error).self) {
            _ = try await repository.nextUpdate()
        }

        #expect(repository.stocks == originalStocks)
        await repository.disconnect()
    }

    @Test
    func emptyOutgoingBatchThrowsWithoutSending() async throws {
        let client = StubWebSocketClient(response: .text("[]"))
        let repository = try makeRepository(client: client, updates: [])
        let originalStocks = repository.stocks
        try await repository.connect()

        await #expect(throws: (any Error).self) {
            _ = try await repository.nextUpdate()
        }

        let sent = await client.lastSent
        #expect(sent == nil)
        #expect(repository.stocks == originalStocks)
        await repository.disconnect()
    }

    private func makeRepository(
        client: StubWebSocketClient,
        updates: [StockPriceMessage] = [
            StockPriceMessage(symbol: "AAPL", price: 105)
        ]
    ) throws -> LiveStockRepository {
        let endpoint = try #require(URL(string: "wss://example.com"))
        return LiveStockRepository(
            client: client,
            endpoint: endpoint,
            stocks: [
                Stock(
                    symbol: "AAPL",
                    name: "Apple",
                    description: "Test stock",
                    currencyCode: "USD",
                    price: 100,
                    change: 2
                )
            ],
            makeUpdates: { _ in updates }
        )
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
