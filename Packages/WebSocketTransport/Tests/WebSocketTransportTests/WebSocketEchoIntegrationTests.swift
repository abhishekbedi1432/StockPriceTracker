//
//  File.swift
//  WebSocketTransport
//
//  Created by Abhishek on 02/11/2026.
//

import Foundation
import Testing
import WebSocketTransport

struct WebSocketEchoIntegrationTests {
    @Test(
        .enabled(
            if: ProcessInfo.processInfo.environment["RUN_WEBSOCKET_INTEGRATION"] == "1"
        )
    )
    func sentTextIsEchoedBack() async throws {
        let url = try #require(
            URL(string: "wss://ws.postman-echo.com/raw")
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15

        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let client = URLSessionWebSocketClient(session: session)

        // Close the socket if the server stops responding.
        let timeoutTask = Task {
            do {
                try await Task.sleep(nanoseconds: 15_000_000_000) //revisit
                await client.disconnect()
            } catch {
                // Cancellation means the test finished before the timeout.
            }
        }
        defer { timeoutTask.cancel() }

        do {
            try await client.connect(to: url)

            let message = WebSocketMessage.text(
                "echo-check-\(UUID().uuidString)"
            )

            try await client.send(message)
            let received = try await client.receive()

            #expect(received == message)

            await client.disconnect()
        } catch {
            await client.disconnect()
            throw error
        }
    }
}


