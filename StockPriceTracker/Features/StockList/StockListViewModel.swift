//
//  StockListViewModel.swift
//  StockPriceTracker
//
//  Created by Abhishek on 02/11/2026.
//

import Foundation
import Observation

enum StockSortOption: CaseIterable, Identifiable {
    case price
    case change

    var id: Self { self }

    func sort(_ stocks: [Stock]) -> [Stock] {
        stocks.sorted { first, second in
            switch self {
            case .price:
                if first.price == second.price {
                    return first.symbol < second.symbol
                }

                return first.price > second.price

            case .change:
                if first.change == second.change {
                    return first.symbol < second.symbol
                }

                return first.change > second.change
            }
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

    var lastError: String? {
        tracking.lastError
    }

    func start() {
        tracking.start()
    }

    func stop() async {
        await tracking.stop()
    }
}
