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

    private let makeUpdates:
        @MainActor ([Stock]) -> [StockPriceMessage]

    init(
        client: any WebSocketClient,
        endpoint: URL,
        stocks: [Stock],
        makeUpdates: @escaping @MainActor ([Stock]) -> [StockPriceMessage] = {
            PriceSimulator.makeUpdates(for: $0)
        }
    ) {
        self.client = client
        self.endpoint = endpoint
        self.stocks = stocks
        self.makeUpdates = makeUpdates
    }

    func connect() async throws {
        try await client.connect(to: endpoint)
    }

    /// Sends a batch of simulated prices and applies the echoed response.
    func nextUpdate() async throws -> [Stock] {
        let proposedUpdates = makeUpdates(stocks)
        guard !proposedUpdates.isEmpty else {
            throw FeedError.noStocks
        }

        let data = try JSONEncoder().encode(proposedUpdates)
        let text = String(decoding: data, as: UTF8.self)

        try await client.send(.text(text))

        let response = try await client.receive()
        try Task.checkCancellation()

        switch response {
        case .text(let text):
            let echoedUpdates = try JSONDecoder().decode(
                [StockPriceMessage].self,
                from: Data(text.utf8)
            )

            // Validate the entire batch before publishing any changes.
            var updatedStocks = stocks
            for update in echoedUpdates {
                guard let index = updatedStocks.firstIndex(
                    where: { $0.symbol == update.symbol }
                ) else {
                    throw FeedError.unknownSymbol(update.symbol)
                }

                updatedStocks[index].applyPrice(update.price)
            }
            stocks = updatedStocks
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
