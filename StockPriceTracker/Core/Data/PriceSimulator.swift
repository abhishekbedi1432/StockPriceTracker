//
//  PriceSimulator.swift
//  StockPriceTracker
//
//  Created by Abhishek on 02/11/2026.
//

import Foundation

struct PriceSimulator {
    static func makeInitialStocks(currencyCode: String) -> [Stock] {
        let companies: [(symbol: String, name: String, description: LocalizedStringResource)] = [
            ("AAPL", "Apple", "Apple designs personal devices, software, and digital services."),
            ("GOOG", "Alphabet", "Alphabet develops internet search, advertising, and cloud services."),
            ("TSLA", "Tesla", "Tesla develops electric vehicles and energy storage products."),
            ("AMZN", "Amazon", "Amazon operates online retail, logistics, and cloud computing services."),
            ("MSFT", "Microsoft", "Microsoft develops productivity software, cloud services, and computing platforms."),
            ("NVDA", "NVIDIA", "NVIDIA designs graphics processors and accelerated computing platforms."),
            ("META", "Meta", "Meta develops social networking, messaging, and virtual reality products."),
            ("NFLX", "Netflix", "Netflix provides streaming entertainment and produces films and series."),
            ("BABA", "Alibaba", "Alibaba provides commerce platforms and cloud computing services."),
            ("ORCL", "Oracle", "Oracle develops database software, business applications, and cloud services."),
            ("INTC", "Intel", "Intel designs and manufactures processors and other semiconductor products."),
            ("AMD", "AMD", "AMD designs processors and graphics technology for computers and data centers."),
            ("IBM", "IBM", "IBM provides enterprise software, infrastructure, and consulting services."),
            ("CSCO", "Cisco", "Cisco develops networking, security, and collaboration technology."),
            ("ADBE", "Adobe", "Adobe develops software for creative work, documents, and digital experiences."),
            ("CRM", "Salesforce", "Salesforce provides cloud software for customer relationship management."),
            ("UBER", "Uber", "Uber operates platforms for ride booking and delivery services."),
            ("LYFT", "Lyft", "Lyft operates a platform that connects riders with drivers."),
            ("SHOP", "Shopify", "Shopify provides software and services that help merchants sell online and in person."),
            ("SQ", "Block", "Block develops payment and financial technology products. This demo uses the historical SQ symbol."),
            ("TWTR", "Twitter", "Twitter developed a social networking service. This demo uses its historical TWTR symbol."),
            ("SNAP", "Snap", "Snap develops Snapchat and camera-based communication products."),
            ("PINS", "Pinterest", "Pinterest operates a visual discovery platform for ideas and inspiration."),
            ("ZM", "Zoom", "Zoom provides video meetings and workplace communication software."),
            ("DOCU", "DocuSign", "DocuSign provides electronic signature and agreement management software.")
        ]

        return companies.map { company in
            let initialPriceInCents = Int.random(in: 10_000...50_000)

            return Stock(
                symbol: company.symbol,
                name: company.name,
                description: company.description,
                currencyCode: currencyCode,
                price: Decimal(initialPriceInCents) / 100,
                change: 0
            )
        }
    }

    static func makeUpdates(for stocks: [Stock]) -> [StockPriceMessage] {
        guard !stocks.isEmpty else { return [] }

        let count = Int.random(in: min(2, stocks.count)...min(6, stocks.count))
        return stocks.shuffled().prefix(count).map { stock in
            makeUpdate(for: stock, movementInCents: Int.random(in: -500...500))
        }
    }

    static func makeUpdate(for stock: Stock, movementInCents: Int) -> StockPriceMessage {
        let movement = Decimal(movementInCents) / 100
        // Keep the simulated price positive even after repeated downward moves.
        let minimumPrice = Decimal(1) / 100
        return StockPriceMessage(
            symbol: stock.symbol,
            price: max(minimumPrice, stock.price + movement)
        )
    }
}
