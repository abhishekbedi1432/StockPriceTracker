//
//  File.swift
//  WebSocketTransport
//
//  Created by Abhishek on 02/11/2026.
//

public enum WebSocketError: Error, Equatable {
    case notConnected
    case connectionAlreadyStarted
    case unsupportedMessage
    case invalidURL
}
