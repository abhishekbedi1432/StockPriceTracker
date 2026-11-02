//
//  PriceChangeView.swift
//  StockPriceTracker
//
//  Created by Abhishek on 02/11/2026.
//

import Foundation
import SwiftUI

struct PriceChangeView: View {
    let change: Decimal

    private var color: Color {
        if change > 0 { return .green }
        if change < 0 { return .red }
        return .secondary
    }

    private var symbol: String {
        if change > 0 { return "arrow.up.right" }
        if change < 0 { return "arrow.down.right" }
        return "minus"
    }

    private var accessibilityTitle: LocalizedStringKey {
        if change > 0 { return "Price increased" }
        if change < 0 { return "Price decreased" }
        return "Price unchanged"
    }

    var body: some View {
        Label {
            Text(
                change,
                format: .number.precision(.fractionLength(2))
            )
            .monospacedDigit()
        } icon: {
            Image(systemName: symbol)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.18), in: RoundedRectangle(
            cornerRadius: 7
        ))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityTitle))
        .accessibilityValue(
            Text(
                change,
                format: .number.precision(.fractionLength(2))
            )
        )
    }
}
