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

    @ObservationIgnored
    private var runID: UUID?

    init(repository: any StockRepository) {
        self.repository = repository
        self.stocks = repository.stocks
    }

    func start() {
        guard feedTask == nil, state != .stopping else {
            return
        }

        let id = UUID()
        runID = id
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
        runID = nil

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

            guard runID == id else { return }

            state = .connected

            while true {
                try await Task.sleep(nanoseconds: 1_000_000_000)

                let updatedStocks = try await repository.nextUpdate()
                try Task.checkCancellation()

                guard runID == id else { return }

                stocks = updatedStocks
            }
        } catch {
            // stop() owns cleanup when it has invalidated this run.
            guard runID == id else { return }

            await repository.disconnect()

            guard runID == id else { return }

            state = .failed
            feedTask = nil
            runID = nil
        }
    }
}

