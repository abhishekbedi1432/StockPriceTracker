//
//  StockRowView.swift
//  StockPriceTracker
//
//  Created by Abhishek on 02/11/2026.
//

import Foundation
import SwiftUI

struct StockRowView: View {
    let stock: Stock

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    identity
                    pricing
                }
            } else {
                HStack(alignment: .center, spacing: 16) {
                    identity
                    Spacer(minLength: 8)
                    pricing
                }
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(stock.symbol)
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Text(stock.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var pricing: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(
                stock.price,
                format: .currency(code: stock.currencyCode)
            )
            .font(.headline)
            .monospacedDigit()
            .foregroundStyle(.primary)

            PriceChangeView(change: stock.change)
        }
    }
}
