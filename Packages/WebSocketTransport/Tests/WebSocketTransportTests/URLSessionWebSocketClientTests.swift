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
            #expect(
                error as? WebSocketError == .notConnected
            )
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
}
