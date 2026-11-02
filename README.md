# Stock Price Tracker

A SwiftUI assessment app displaying simulated prices for 25 stock symbols. Prices travel through `wss://ws.postman-echo.com/raw`; the app applies the echoed response rather than updating directly from the generated values. This is not a live market-data service.

## Run locally

Developed with Xcode 27.1 and Swift 6.4. The local WebSocket package requires Swift tools 6.4. The app and app tests target iOS 17.0 or later. The reusable WebSocket package retains its iOS 15 minimum and is compatible with the app target. Use an iOS 17 or newer simulator.

1. Open `StockPriceTracker.xcodeproj` in Xcode.
2. Select the `StockPriceTracker` scheme and an installed iOS simulator.
3. Build and run. Tap **Start** to connect and begin updates.
4. Change the sorting option or select a stock to view its details. Tap **Stop** on the list screen to disconnect.

Internet access is required for the feed. No API key is needed. For a physical device, select your own development team in Signing & Capabilities.

## Behavior

- Each cycle generates updates for 2–6 distinct randomly selected stocks and sends them as one JSON array.
- The feed waits 0.5 seconds before each batch. Network round-trip time adds to that interval.
- Movements range from −5.00 to +5.00; simulated prices have a floor of 0.01.
- Price change means the difference from that stock's previous received price, not daily change or percentage change. Stocks outside the batch retain their previous indicator.
- Both sorting options are descending. Price-change sorting uses signed values, with symbol order breaking ties.
- List and detail view models share one tracking service, so the selected symbol continues receiving updates while its details are displayed.
- Connection states include disconnected, connecting, connected, stopping, and failed. Failed connections can be retried manually.
- Entering the background stops the feed and preserves the latest prices. Returning to the foreground stays disconnected until **Start** is tapped again.
- Each connect/send/receive on the transport client must finish within 15 seconds or fails with `operationTimedOut`.

## Architecture

`View → ViewModel → StockTrackingService → StockRepository → WebSocketClient`

- **Features:** list and detail views with their presentation models.
- **Core/Application:** the observable tracking service owns the feed task, shared prices, and connection state. Cancellation and run identity checks prevent stopped runs from publishing late results.
- **Core/Domain:** stock values, feed states, and the repository contract. Prices use `Decimal`.
- **Core/Data:** the simulator and repository encode proposals, decode echoed batches, and validate the whole batch before replacing stored prices.
- **Core/Presentation:** the reusable price-change indicator.
- **Packages/WebSocketTransport:** an actor-backed URLSession transport with no stock-specific dependencies. Socket identity checks protect a replacement connection from stale work.

Direct asynchronous `send` and `receive` operations suit the required echo workflow. An `AsyncStream` wrapper is not necessary. A real server-push feed would need independent receiving rather than assuming each send has one corresponding response.

## Tests

The app tests use Swift Testing and controlled dependencies rather than the public echo server. They cover:

- price arithmetic and positive-price floor
- JSON decoding and batch rollback (malformed payload, unknown symbol, empty batch)
- send/receive transport failures through the repository
- sorting and tie-break rules
- shared list/detail values and late responses during Stop
- connection cancellation, connection failure retry, active-feed failure retry
- malformed batches failing the service without publishing partial prices
- catalog generation for all 25 symbols
- SwiftUI hosting for list, detail, row, price-change, and `ContentView` branches
- the background-stops-the-feed lifecycle policy

Repository stubs park on a cancellation-aware gate (`StockPriceTrackerTests/ParkGate.swift`). A stop always resumes the feed task, because a late `nextUpdate()` call would otherwise leave `stop()` awaiting a task that can never finish.

In Xcode, select the `StockPriceTracker` scheme and use **Product → Test**. Enable code coverage under the scheme’s Test options when measuring line coverage.

For the transport suite, open `Packages/WebSocketTransport/Package.swift`, select the `WebSocketTransport` scheme and an iOS simulator, then use **Product → Test**. These tests need no network and cover the client’s validation and failure paths: send/receive while disconnected, unsupported scheme, missing host, scheme-less URL, uppercase scheme, repeated disconnect, cleanup after a failed connect, and error/message equality.

The successful handshake, send/receive round trip, binary rejection, and operation deadline all require a live socket. They are covered by the echo integration test, gated by `RUN_WEBSOCKET_INTEGRATION=1`; leave that unset for offline runs. The package deliberately contains no in-process fake WebSocket server: the framing and SHA-1 handshake it would need are protocol code we would have to maintain, and the real handshake is already exercised against the public echo endpoint.

```sh
# From the repository root: app tests
xcodebuild test -project StockPriceTracker.xcodeproj \
  -scheme StockPriceTracker \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' \
  -enableCodeCoverage YES

# Separately: transport unit tests (no external network)
cd Packages/WebSocketTransport
xcodebuild test -scheme WebSocketTransport \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' \
  -skip-testing:WebSocketTransportTests/WebSocketEchoIntegrationTests \
  -enableCodeCoverage YES

# Opt-in live echo check
RUN_WEBSOCKET_INTEGRATION=1 swift test --filter WebSocketEchoIntegrationTests
```

## CI

GitHub Actions workflow: `.github/workflows/ci.yml`.

- **App tests** on `macos-15` with an explicit iPhone simulator destination and code coverage enabled.
- **WebSocketTransport unit tests** on the same runner image; integration suite skipped by default.
- **Echo integration** runs only when the repository variable `RUN_WEBSOCKET_INTEGRATION` is `true`.

The workflow selects the runner’s default `Xcode.app`. Because this project needs Swift 6.4, confirm the GitHub-hosted image provides a matching toolchain before relying on CI, or point `XCODE_APP` at a suitable installed Xcode.

## Regional support

The string catalog includes Arabic translations for UI chrome and all 25 company descriptions. Currency and date formatting use locale-aware format styles; simulated instruments remain USD-denominated. Company and ticker names stay in their market form. Verify Arabic RTL layout, Dynamic Type, and iPhone/iPad navigation on device or simulator before submission.

## Source control

Keep each behavior change and its tests in a focused commit. Run the affected checks before committing, and keep personal Xcode state out of submissions. Review changes through pull requests when collaborating. Publish a public GitHub repository URL with the assessment submission once the remote is configured.
