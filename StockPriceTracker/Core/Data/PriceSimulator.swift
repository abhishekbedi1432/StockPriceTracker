//
//  PriceSimulator.swift
//  StockPriceTracker
//
//  Created by Abhishek on 02/11/2026.
//

import Foundation

struct PriceSimulator {
    static func makeInitialStocks(currencyCode: String) -> [Stock] {
        let companies: [(symbol: String, name: String)] = [
            ("AAPL", "Apple"),
            ("GOOG", "Alphabet"),
            ("TSLA", "Tesla"),
            ("AMZN", "Amazon"),
            ("MSFT", "Microsoft"),
            ("NVDA", "NVIDIA"),
            ("META", "Meta"),
            ("NFLX", "Netflix"),
            ("BABA", "Alibaba"),
            ("ORCL", "Oracle"),
            ("INTC", "Intel"),
            ("AMD", "AMD"),
            ("IBM", "IBM"),
            ("CSCO", "Cisco"),
            ("ADBE", "Adobe"),
            ("CRM", "Salesforce"),
            ("UBER", "Uber"),
            ("LYFT", "Lyft"),
            ("SHOP", "Shopify"),
            ("SQ", "Block"),
            ("TWTR", "Twitter"),
            ("SNAP", "Snap"),
            ("PINS", "Pinterest"),
            ("ZM", "Zoom"),
            ("DOCU", "DocuSign")
        ]

        return companies.map { company in
            let initialPriceInCents = Int.random(in: 10_000...50_000)

            return Stock(
                symbol: company.symbol,
                name: company.name,
                description: "Stock-price updates for \(company.name).",
                currencyCode: currencyCode,
                price: Decimal(initialPriceInCents) / 100,
                change: 0
            )
        }
    }

    static func makeUpdate(
        for stocks: [Stock]
    ) -> StockPriceMessage? {
        guard let stock = stocks.randomElement() else {
            return nil
        }

        let movementInCents = Int.random(in: -500...500)
        let movement = Decimal(movementInCents) / 100

        return StockPriceMessage(
            symbol: stock.symbol,
            price: stock.price + movement
        )
    }
}
