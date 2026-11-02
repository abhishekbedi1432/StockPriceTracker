//
//  LiveStockRepository.swift
//  StockPriceTracker
//
//  Created by Abhishek on 02/11/2026.
//

import Foundation
import WebSocketTransport

@MainActor
final class LiveStockRepository: StockRepository {
    private(set) var stocks: [Stock]

    private let client: any WebSocketClient
    private let endpoint: URL

    private let makeUpdate:
        @MainActor ([Stock]) -> StockPriceMessage?

    init(
        client: any WebSocketClient,
        endpoint: URL,
        stocks: [Stock],
        makeUpdate: @escaping @MainActor ([Stock]) -> StockPriceMessage? = {
            PriceSimulator.makeUpdate(for: $0)
        }
    ) {
        self.client = client
        self.endpoint = endpoint
        self.stocks = stocks
        self.makeUpdate = makeUpdate
    }

    func connect() async throws {
        try await client.connect(to: endpoint)
    }

    /// Sends a simulated price to the echo server and applies the echoed response.
    func nextUpdate() async throws -> [Stock] {
        guard let proposedUpdate = makeUpdate(stocks) else {
            throw FeedError.noStocks
        }

        let data = try JSONEncoder().encode(proposedUpdate)
        let text = String(decoding: data, as: UTF8.self)

        try await client.send(.text(text))

        let response = try await client.receive()
        try Task.checkCancellation()

        switch response {
        case .text(let text):
            let echoedUpdate = try JSONDecoder().decode(
                StockPriceMessage.self,
                from: Data(text.utf8)
            )

            guard let index = stocks.firstIndex(
                where: { $0.symbol == echoedUpdate.symbol }
            ) else {
                throw FeedError.unknownSymbol(echoedUpdate.symbol)
            }

            stocks[index].applyPrice(echoedUpdate.price)
        }

        return stocks
    }

    func disconnect() async {
        await client.disconnect()
    }
}

private enum FeedError: Error {
    case noStocks
    case unknownSymbol(String)
}
