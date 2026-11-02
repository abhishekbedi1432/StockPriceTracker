//
//  StockListView.swift
//  StockPriceTracker
//
//  Created by Abhishek on 02/11/2026.
//

import Foundation
import SwiftUI

struct StockListView: View {
    @Bindable var viewModel: StockListViewModel
    @Binding var selection: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            header

            List(selection: $selection) {
                ForEach(viewModel.stocks) { stock in
                    NavigationLink(value: stock.symbol) {
                        StockRowView(stock: stock)
                    }
                    .listRowBackground(Color.black)
                    .listRowSeparatorTint(.white.opacity(0.18))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(Color.black)
        .navigationTitle("Stocks")
        .navigationBarTitleDisplayMode(.large)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            dateHeading
            connectionControls
            sortPicker

            if viewModel.state == .failed {
                Text("The feed stopped. Please try again.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            Text("Simulated prices")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    private var dateHeading: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Text(
                context.date,
                format: .dateTime.day().month(.wide)
            )
            .font(.title2.bold())
            .foregroundStyle(.secondary)
        }
    }

    private var connectionControls: some View {
        HStack {
            Label {
                Text(statusTitle)
            } icon: {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
            .font(.subheadline)

            Spacer()

            Button(action: handleFeedAction) {
                Text(buttonTitle)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(viewModel.state == .stopping)
        }
    }

    @ViewBuilder
    private var sortPicker: some View {
        if dynamicTypeSize.isAccessibilitySize {
            sortOptions
                .pickerStyle(.menu)
        } else {
            sortOptions
                .pickerStyle(.segmented)
        }
    }

    private var sortOptions: some View {
        Picker("Sort by", selection: $viewModel.sortOption) {
            Text("Price")
                .tag(StockSortOption.price)

            Text("Price Change")
                .tag(StockSortOption.change)
        }
    }

    private var statusTitle: LocalizedStringKey {
        switch viewModel.state {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting…"
        case .connected:
            return "Connected"
        case .stopping:
            return "Stopping…"
        case .failed:
            return "Connection failed"
        }
    }

    private var statusColor: Color {
        switch viewModel.state {
        case .connected:
            return .green
        case .connecting, .stopping:
            return .orange
        case .failed:
            return .red
        case .disconnected:
            return .secondary
        }
    }

    private var buttonTitle: LocalizedStringKey {
        switch viewModel.state {
        case .connected:
            return "Stop"
        case .connecting:
            return "Cancel"
        case .stopping:
            return "Stopping…"
        case .failed:
            return "Retry"
        case .disconnected:
            return "Start"
        }
    }

    func handleFeedAction() {
        switch viewModel.state {
        case .disconnected, .failed:
            viewModel.start()

        case .connecting, .connected:
            Task {
                await viewModel.stop()
            }

        case .stopping:
            break
        }
    }
}
