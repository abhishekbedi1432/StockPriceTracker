//
//  StockRepository.swift
//  StockPriceTracker
//
//  Created by Abhishek on 02/11/2026.
//

import Foundation

@MainActor
protocol StockRepository {
    var stocks: [Stock] { get }

    func connect() async throws
    func nextUpdate() async throws -> [Stock]
    func disconnect() async
}
