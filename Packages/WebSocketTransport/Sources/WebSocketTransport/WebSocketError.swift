//
//  File.swift
//  WebSocketTransport
//
//  Created by Abhishek on 02/11/2026.
//

public enum WebSocketError: Error, Equatable, Sendable {
    case notConnected
    case connectionAlreadyStarted
    case unsupportedMessage
    case invalidURL
    /// Connect, send, or receive did not finish within the client deadline.
    case operationTimedOut
}
