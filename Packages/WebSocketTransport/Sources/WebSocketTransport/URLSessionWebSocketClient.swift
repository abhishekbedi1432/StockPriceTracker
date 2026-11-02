//
//  File.swift
//  WebSocketTransport
//
//  Created by Abhishek on 02/11/2026.
//

import Foundation
public actor URLSessionWebSocketClient: WebSocketClient {
    private let session: URLSession
    private var socket: URLSessionWebSocketTask?
    private var isConnected = false

    public init(session: URLSession = .shared) {
        self.session = session
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

        do {
            try await confirmConnection(using: task)

            try Task.checkCancellation()

            guard socket === task else {
                throw CancellationError()
            }

            isConnected = true
        } catch {
            close(task)
            throw error
        }
    }

    public func send(_ message: WebSocketMessage) async throws {
        let task = try connectedSocket()

        do {
            switch message {
            case .text(let text):
                try await task.send(.string(text))
            }
        } catch {
            close(task)
            throw error
        }
    }

    public func receive() async throws -> WebSocketMessage {
        let task = try connectedSocket()

        do {
            let message = try await task.receive()

            // Ignore results from a connection that has been replaced.
            guard socket === task else {
                throw CancellationError()
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
            close(task)
            throw error
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
