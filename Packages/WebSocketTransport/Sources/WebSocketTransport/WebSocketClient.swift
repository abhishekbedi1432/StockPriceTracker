//
//  WebSocketClient.swift
//  WebSocketTransport
//
//  Created by Abhishek on 02/11/2026.
//

import Foundation

public protocol WebSocketClient: Sendable {

    func connect(to url: URL) async throws
    func send(_ message: WebSocketMessage) async throws
    func receive() async throws -> WebSocketMessage
    func disconnect() async
}
