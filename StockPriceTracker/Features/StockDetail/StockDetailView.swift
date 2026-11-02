//
//  StockDetailView.swift
//  StockPriceTracker
//
//  Created by Abhishek on 02/11/2026.
//

import Foundation
import SwiftUI

struct StockDetailView: View {
    let viewModel: StockDetailViewModel

    var body: some View {
        Group {
            if let stock = viewModel.stock {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(stock.name)
                                .font(.title2)
                                .foregroundStyle(.secondary)

                            Text(
                                stock.price,
                                format: .currency(
                                    code: stock.currencyCode
                                )
                            )
                            .font(.largeTitle.bold())
                            .monospacedDigit()

                            PriceChangeView(change: stock.change)

                            Text("Change since the previous update")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 10) {
                            Text("About")
                                .font(.headline)

                            Text(stock.description)
                                .foregroundStyle(.secondary)
                        }

                        Label(
                            "Simulated prices",
                            systemImage: "info.circle"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                }
            } else {
                ContentUnavailableView(
                    "Stock unavailable",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text(
                        "Choose another stock from the list."
                    )
                )
            }
        }
        .background(Color.black)
        .navigationTitle(viewModel.symbol)
        .navigationBarTitleDisplayMode(.inline)
    }
}
