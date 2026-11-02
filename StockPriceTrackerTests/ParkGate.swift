import Foundation

/// Cancellation-aware parking gate for test repositories.
///
/// A feed task can reach `nextUpdate()`/`connect()` *after* `disconnect()` has already run.
/// Without this gate that continuation is never resumed and `StockTrackingService.stop()`
/// blocks forever on `await task.value`, which hangs the whole test run.
///
/// `park()` therefore fails fast once the gate has been cancelled, so a late arrival can
/// never strand a continuation.
@MainActor
final class ParkGate<Value: Sendable> {
    private var continuation: CheckedContinuation<Value, any Error>?
    private var isCancelled = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// Suspends until resumed, or throws immediately if already cancelled.
    func park() async throws -> Value {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                self.continuation = continuation
                let pending = waiters
                waiters.removeAll()
                pending.forEach { $0.resume() }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancel()
            }
        }
    }

    /// Cancels the gate and fails any parked (or future) continuation.
    func cancel() {
        isCancelled = true
        resume(throwing: CancellationError())
    }

    /// Resumes a parked continuation with a value.
    func resume(returning value: Value) {
        resume { $0.resume(returning: value) }
    }

    /// Resumes a parked continuation with an error.
    func resume(throwing error: any Error) {
        resume { $0.resume(throwing: error) }
    }

    /// Allows the gate to park again after a cancelled run.
    func reset() {
        isCancelled = false
    }

    /// Suspends until the gate is actually parked, so tests can stop deterministically.
    func waitUntilParked() async {
        if continuation != nil { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    var isParked: Bool { continuation != nil }

    private func resume(_ body: (CheckedContinuation<Value, any Error>) -> Void) {
        let pending = continuation
        continuation = nil
        if let pending {
            body(pending)
        }
    }
}
