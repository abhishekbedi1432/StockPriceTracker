//
//  StockListViewModel.swift
//  StockPriceTracker
//
//  Created by Abhishek on 02/11/2026.
//

import Foundation
import Observation

enum StockSortOption: Hashable {
    case price
    case change

    func sort(_ stocks: [Stock]) -> [Stock] {
        let keyPath: KeyPath<Stock, Decimal>
        switch self {
        case .price:
            keyPath = \.price
        case .change:
            keyPath = \.change
        }

        return stocks.sorted { first, second in
            let firstValue = first[keyPath: keyPath]
            let secondValue = second[keyPath: keyPath]

            if firstValue == secondValue {
                return first.symbol < second.symbol
            }

            return firstValue > secondValue
        }
    }
}

@MainActor
@Observable
final class StockListViewModel {
    var sortOption: StockSortOption = .price

    private let tracking: StockTrackingService

    init(tracking: StockTrackingService) {
        self.tracking = tracking
    }

    var stocks: [Stock] {
        sortOption.sort(tracking.stocks)
    }

    var state: FeedState {
        tracking.state
    }

    func start() {
        tracking.start()
    }

    func stop() async {
        await tracking.stop()
    }
}
