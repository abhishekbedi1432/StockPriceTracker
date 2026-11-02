//
//  URLSessionWebSocketClient.swift
//  WebSocketTransport
//
//  Created by Abhishek on 02/11/2026.
//

import Foundation

public actor URLSessionWebSocketClient: WebSocketClient {
    private let session: URLSession
    private let operationTimeoutSeconds: UInt64
    private var socket: URLSessionWebSocketTask?
    private var isConnected = false
    /// Set when the active operation deadline closes the current socket.
    private var timedOutTask: URLSessionWebSocketTask?

    /// Each connect, send, or receive must complete within this deadline.
    public init(session: URLSession = .shared, operationTimeoutSeconds: UInt64 = 15) {
        precondition((1...86_400).contains(operationTimeoutSeconds))
        self.session = session
        self.operationTimeoutSeconds = operationTimeoutSeconds
    }

    public func connect(to url: URL) async throws {
        guard ["ws", "wss"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host,
              !host.isEmpty else {
            throw WebSocketError.invalidURL
        }

        guard socket == nil else {
            throw WebSocketError.connectionAlreadyStarted
        }

        let task = session.webSocketTask(with: url)
        socket = task
        task.resume()
        let timeout = scheduleTimeout(for: task)
        defer { timeout.cancel() }

        do {
            try await confirmConnection(using: task)

            try Task.checkCancellation()

            guard socket === task else {
                throw mapTimeoutIfNeeded(for: task, fallback: CancellationError())
            }

            isConnected = true
        } catch {
            throw finishFailedOperation(task, error: error)
        }
    }

    public func send(_ message: WebSocketMessage) async throws {
        let task = try connectedSocket()
        let timeout = scheduleTimeout(for: task)
        defer { timeout.cancel() }

        do {
            switch message {
            case .text(let text):
                try await task.send(.string(text))
            }
        } catch {
            throw finishFailedOperation(task, error: error)
        }
    }

    public func receive() async throws -> WebSocketMessage {
        let task = try connectedSocket()
        let timeout = scheduleTimeout(for: task)
        defer { timeout.cancel() }

        do {
            let message = try await task.receive()

            // Ignore results from a connection that has been replaced.
            guard socket === task else {
                throw mapTimeoutIfNeeded(for: task, fallback: CancellationError())
            }

            switch message {
            case .string(let text):
                return .text(text)

            case .data:
                throw WebSocketError.unsupportedMessage

            @unknown default:
                throw WebSocketError.unsupportedMessage
            }
        } catch {
            throw finishFailedOperation(task, error: error)
        }
    }

    public func disconnect() async {
        guard let task = socket else { return }
        close(task)
    }

    private func confirmConnection(using task: URLSessionWebSocketTask) async throws {
        // A successful pong confirms the connection is usable.
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, any Error>) in

                task.sendPing { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        } onCancel: {
            task.cancel(with: .goingAway, reason: nil)
        }
    }

    private func scheduleTimeout(for task: URLSessionWebSocketTask) -> Task<Void, Never> {
        let timeoutSeconds = operationTimeoutSeconds
        return Task {
            do {
                try await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                try Task.checkCancellation()
                self.applyTimeout(for: task)
            } catch {
                // A completed operation cancels its deadline.
            }
        }
    }

    private func applyTimeout(for task: URLSessionWebSocketTask) {
        // Never close a replacement connection from an older operation.
        guard socket === task else { return }
        timedOutTask = task
        close(task)
    }

    private func finishFailedOperation(
        _ task: URLSessionWebSocketTask,
        error: any Error
    ) -> any Error {
        let mapped = mapTimeoutIfNeeded(for: task, fallback: error)
        close(task)
        return mapped
    }

    private func mapTimeoutIfNeeded(
        for task: URLSessionWebSocketTask,
        fallback: any Error
    ) -> any Error {
        if timedOutTask === task {
            timedOutTask = nil
            return WebSocketError.operationTimedOut
        }
        return fallback
    }

    private func connectedSocket() throws -> URLSessionWebSocketTask {
        guard isConnected, let socket else {
            throw WebSocketError.notConnected
        }

        return socket
    }

    private func close(_ task: URLSessionWebSocketTask) {
        task.cancel(with: .goingAway, reason: nil)

        guard socket === task else { return }

        socket = nil
        isConnected = false
    }
}
