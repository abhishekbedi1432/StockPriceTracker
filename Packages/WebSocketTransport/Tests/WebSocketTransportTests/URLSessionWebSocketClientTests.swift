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
    func stalledConnectTimesOutWithOperationTimedOut() async throws {
        // Non-routable address keeps the handshake pending until the client deadline.
        let url = try #require(URL(string: "ws://172.16.0.1:9"))
        let client = URLSessionWebSocketClient(operationTimeoutSeconds: 1)

        let started = ContinuousClock.now
        do {
            try await client.connect(to: url)
            Issue.record("Expected a stalled connect to time out.")
        } catch {
            #expect(error as? WebSocketError == .operationTimedOut)
        }

        let elapsed = ContinuousClock.now - started
        #expect(elapsed >= .seconds(1))
        #expect(elapsed < .seconds(5))

        // Timed-out connect must leave the client reusable.
        do {
            try await client.send(.text("after-timeout"))
            Issue.record("Expected the client to remain disconnected after timeout.")
        } catch {
            #expect(error as? WebSocketError == .notConnected)
        }
    }
}
