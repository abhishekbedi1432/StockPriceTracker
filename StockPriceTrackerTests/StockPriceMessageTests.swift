//
//  StockPriceMessageTests.swift
//  StockPriceTrackerTests
//
//  Created by Abhishek on 02/11/2026.
//

import Foundation
import Testing
@testable import StockPriceTracker

@MainActor
struct StockPriceMessageTests {
    @Test
    func decodesSymbolAndDecimalPrice() throws {
        let data = Data(
            #"{"symbol":"AAPL","price":105.25}"#.utf8
        )

        let message = try JSONDecoder().decode(
            StockPriceMessage.self,
            from: data
        )

        #expect(message.symbol == "AAPL")
        #expect(message.price == Decimal(10525) / Decimal(100))
    }

    @Test
    func rejectsMessageWithoutPrice() {
        let data = Data(
            #"{"symbol":"AAPL"}"#.utf8
        )

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                StockPriceMessage.self,
                from: data
            )
        }
    }
}

