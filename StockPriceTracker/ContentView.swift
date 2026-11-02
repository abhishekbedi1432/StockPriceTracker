//
//  ContentView.swift
//  StockPriceTracker
//
//  Created by Abhishek on 02/11/2026.
//

import SwiftUI

struct ContentView: View {
    private let tracking: StockTrackingService

    @State private var listViewModel: StockListViewModel
    @State private var selectedSymbol: String?

    init(
        tracking: StockTrackingService,
        selectedSymbol: String? = nil
    ) {
        self.tracking = tracking

        _listViewModel = State(
            initialValue: StockListViewModel(
                tracking: tracking
            )
        )
        _selectedSymbol = State(initialValue: selectedSymbol)
    }

    var body: some View {
        NavigationSplitView {
            StockListView(
                viewModel: listViewModel,
                selection: $selectedSymbol
            )
            .navigationSplitViewColumnWidth(
                min: 320,
                ideal: 420
            )
        } detail: {
            if let selectedSymbol {
                StockDetailView(
                    viewModel: StockDetailViewModel(
                        symbol: selectedSymbol,
                        tracking: tracking
                    )
                )
                .id(selectedSymbol)
            } else {
                ContentUnavailableView(
                    "Select a stock",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text(
                        "Choose a symbol to see its latest price."
                    )
                )
                .background(Color.black)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .preferredColorScheme(.dark)
    }
}
