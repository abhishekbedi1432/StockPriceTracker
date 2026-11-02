//
//  StockTrackingService.swift
//  StockPriceTracker
//
//  Created by Abhishek on 02/11/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class StockTrackingService {
    private(set) var stocks: [Stock]
    private(set) var state: FeedState = .disconnected

    private let repository: any StockRepository

    @ObservationIgnored
    private var feedTask: Task<Void, Never>?

    // Identifies the run allowed to publish updates after suspension points.
    @ObservationIgnored
    private var activeRunID: UUID?

    init(repository: any StockRepository) {
        self.repository = repository
        self.stocks = repository.stocks
    }

    func start() {
        guard feedTask == nil, state != .stopping else {
            return
        }

        let id = UUID()
        activeRunID = id
        state = .connecting

        feedTask = Task { [weak self] in
            guard let self else { return }
            await self.runFeed(id: id)
        }
    }

    func stop() async {
        guard let task = feedTask, state != .stopping else {
            return
        }

        state = .stopping
        // Invalidate before awaiting disconnection so this stop owns cleanup.
        activeRunID = nil

        task.cancel()
        await repository.disconnect()
        await task.value

        feedTask = nil
        state = .disconnected
    }

    private func runFeed(id: UUID) async {
        do {
            try await repository.connect()
            try Task.checkCancellation()

            guard activeRunID == id else { return }

            state = .connected

            while true {
                try await Task.sleep(for: .seconds(0.5))

                let updatedStocks = try await repository.nextUpdate()
                try Task.checkCancellation()

                guard activeRunID == id else { return }

                stocks = updatedStocks
            }
        } catch {
            // stop() owns cleanup when it has invalidated this run.
            guard activeRunID == id else { return }

            await repository.disconnect()

            guard activeRunID == id else { return }

            state = .failed
            feedTask = nil
            activeRunID = nil
        }
    }
}

