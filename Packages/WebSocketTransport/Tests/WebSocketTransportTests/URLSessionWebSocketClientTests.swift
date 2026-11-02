import Foundation
import Testing
@testable import WebSocketTransport

struct URLSessionWebSocketClientTests {
    @Test
    func sendBeforeConnectingThrowsNotConnected() async {
        let client = URLSessionWebSocketClient()

        do {
            try await client.send(.text("Hello"))
            Issue.record("Expected sending while disconnected to throw.")
        } catch {
            #expect(error as? WebSocketError == .notConnected)
        }
    }

    @Test
    func receiveBeforeConnectingThrowsNotConnected() async {
        let client = URLSessionWebSocketClient()

        do {
            _ = try await client.receive()
            Issue.record("Expected receiving while disconnected to throw.")
        } catch {
            #expect(error as? WebSocketError == .notConnected)
        }
    }

    @Test
    func connectWithHTTPSURLThrowsInvalidURL() async throws {
        let url = try #require(URL(string: "https://example.com"))
        let client = URLSessionWebSocketClient()

        do {
            try await client.connect(to: url)
            Issue.record("Expected an unsupported URL scheme to throw.")
        } catch {
            #expect(error as? WebSocketError == .invalidURL)
        }
    }

    @Test
    func connectWithoutHostThrowsInvalidURL() async throws {
        let url = try #require(URL(string: "wss://"))
        let client = URLSessionWebSocketClient()

        do {
            try await client.connect(to: url)
            Issue.record("Expected a missing host to throw.")
        } catch {
            #expect(error as? WebSocketError == .invalidURL)
        }
    }

    @Test
    func disconnectWhileDisconnectedIsSafe() async {
        let client = URLSessionWebSocketClient()
        await client.disconnect()
        await client.disconnect()
    }

    @Test
    func failedConnectCleansUpAndLeavesClientDisconnected() async throws {
        // Port 1 on loopback is closed, so the handshake fails without external network.
        let url = try #require(URL(string: "ws://127.0.0.1:1"))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let client = URLSessionWebSocketClient(session: session, operationTimeoutSeconds: 10)

        do {
            try await client.connect(to: url)
            Issue.record("Expected connecting to a closed port to fail.")
        } catch {
            // The failure must not be reported as a client deadline.
            #expect(error as? WebSocketError != .operationTimedOut)
        }

        // A failed connect must release the socket so the client reports not connected.
        do {
            try await client.send(.text("after-failure"))
            Issue.record("Expected send after a failed connect to throw.")
        } catch {
            #expect(error as? WebSocketError == .notConnected)
        }

        // Cleanup must be repeatable and a retry must be allowed to fail again.
        await client.disconnect()
        do {
            try await client.connect(to: url)
            Issue.record("Expected a retried connect to a closed port to fail.")
        } catch {
            #expect(error as? WebSocketError != .operationTimedOut)
        }
    }

    @Test
    func webSocketMessageAndErrorEquality() {
        #expect(WebSocketMessage.text("a") == WebSocketMessage.text("a"))
        #expect(WebSocketMessage.text("a") != WebSocketMessage.text("b"))

        #expect(WebSocketError.notConnected == .notConnected)
        #expect(WebSocketError.connectionAlreadyStarted == .connectionAlreadyStarted)
        #expect(WebSocketError.unsupportedMessage == .unsupportedMessage)
        #expect(WebSocketError.invalidURL == .invalidURL)
        #expect(WebSocketError.operationTimedOut == .operationTimedOut)
        #expect(WebSocketError.notConnected != .invalidURL)
    }
}
