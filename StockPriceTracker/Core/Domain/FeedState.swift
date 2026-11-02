//
//  FeedState.swift
//  StockPriceTracker
//
//  Created by Abhishek on 02/11/2026.
//

enum FeedState: Equatable {
    case disconnected
    case connecting
    case connected
    case stopping
    case failed
}
