# Stock Price Tracker

SwiftUI assessment app showing simulated prices for 25 stock symbols. Prices round-trip through `wss://ws.postman-echo.com/raw` and the app applies the echo, not the generated value. Not a live market-data service.

## Run locally

Xcode 27.1 / Swift 6.4, iOS 17+. Open `StockPriceTracker.xcodeproj`, select the `StockPriceTracker` scheme and a simulator, run, then tap **Start**. Internet is required; no API key.

## Behavior

- Batches of 2–6 randomly chosen stocks every 0.5s; moves of ±5.00 with a 0.01 price floor.
- Change is the difference from that stock's previous received price, not daily or percentage change.
- Both sorts are descending; price-change uses signed values and symbol order breaks ties.
- One shared feed serves list and detail, so prices stay synchronized and keep updating in detail.
- States: disconnected, connecting, connected, stopping, failed. Failures retry manually.
- Backgrounding stops the feed and keeps prices; **Start** is required again on return.
- Each transport operation must finish within 15s or fails with `operationTimedOut`.

## Architecture

`View → ViewModel → StockTrackingService → StockRepository → WebSocketClient`

- **Features** list/detail views and presentation models; **Core/Application** the observable service owning the feed task, prices, and state; **Core/Domain** stock values, feed states, repository contract (`Decimal` prices); **Core/Data** simulator, JSON encode/decode, whole-batch validation; **Core/Presentation** the price-change indicator; **Packages/WebSocketTransport** an actor-backed URLSession transport with no stock knowledge.
- Cancellation plus run-identity checks stop a stopped run publishing late results; socket-identity checks protect a replacement connection.
- Plain async `send`/`receive` fit this echo workflow. A server-push feed would need independent receiving.

## Tests

App tests use Swift Testing with controlled dependencies, never the public server. They cover price arithmetic and the price floor, JSON decoding and batch rollback, send/receive failures, sorting and ties, shared list/detail values plus late results during Stop, connection and active-feed failure retry, catalog generation, SwiftUI hosting, and the background lifecycle.

Repository stubs park on a cancellation-aware gate (`StockPriceTrackerTests/ParkGate.swift`) so `stop()` can always resume the feed task.

Run app tests with **Product → Test**; enable coverage under the scheme's Test options. Transport tests need no network and cover disconnected send/receive, invalid URLs (unsupported scheme, missing host, scheme-less), uppercase scheme, repeated disconnect, cleanup after a failed connect, and error equality. The handshake, send/receive round trip, binary rejection, and operation deadline need a live socket and live in the `RUN_WEBSOCKET_INTEGRATION=1` echo test. No fake WebSocket server is included, deliberately.

```sh
xcodebuild test -project StockPriceTracker.xcodeproj -scheme StockPriceTracker \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' -enableCodeCoverage YES

cd Packages/WebSocketTransport
xcodebuild test -scheme WebSocketTransport \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' \
  -skip-testing:WebSocketTransportTests/WebSocketEchoIntegrationTests -enableCodeCoverage YES

RUN_WEBSOCKET_INTEGRATION=1 swift test --filter WebSocketEchoIntegrationTests
```

## CI

`.github/workflows/ci.yml` runs app tests and transport unit tests on `macos-15` with an explicit iPhone destination and coverage enabled, and runs the echo integration only when the repository variable `RUN_WEBSOCKET_INTEGRATION` is `true`. The runner's default Xcode must supply Swift 6.4, or point `XCODE_APP` at a suitable install.

## Regional support

The catalog translates all UI chrome and all 25 company descriptions into Arabic. Formatting is locale-aware and quotes stay USD. Verify RTL, Dynamic Type, and iPhone/iPad navigation manually.

## Source control

One focused commit per behavior change, with its tests. Keep Xcode user state out of submissions and publish the public repository URL with the assessment.
