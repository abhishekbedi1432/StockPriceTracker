# Stock Price Tracker

A SwiftUI assessment app displaying simulated prices for 25 stock symbols. Prices travel through `wss://ws.postman-echo.com/raw`; the app applies the echoed response rather than updating directly from the generated values. This is not a live market-data service.

## Run locally

The development environment is Xcode 27.1 with Swift 6.4. The local WebSocket package requires Swift tools 6.4. App deployment currently uses Xcode's recommended iOS deployment target; the project and app test settings also contain iOS 27.0. Use a compatible iOS simulator. Older toolchains have not been validated.

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

The app tests use Swift Testing and controlled dependencies rather than the public echo server. They cover price arithmetic, JSON decoding, batch rollback, sorting, connection cancellation, shared list/detail values, late responses during Stop, and simulator price boundaries. Asynchronous tests synchronize on repository events; the shared-update test still uses the service's production pacing interval.

In Xcode, select the `StockPriceTracker` scheme and use **Product → Test**. The latest local app run passed 26 test cases. This suite does not include the package tests.

For the transport suite, open `Packages/WebSocketTransport/Package.swift`, select the `WebSocketTransport` scheme and an iOS simulator, then use **Product → Test**. Unit tests cover disconnected operations and invalid URLs. The echo integration test is gated by `RUN_WEBSOCKET_INTEGRATION=1`; explicitly disable that variable for offline runs and enable it only for the live-server check. Inspect the scheme's Test environment rather than assuming its current setting.

Command-line templates for automation follow. Replace `SIMULATOR_UDID` with an installed, compatible simulator identifier. These templates must be validated on the chosen CI runner; no CI workflow is included yet.

```sh
# From the repository root: app tests
xcodebuild test -project StockPriceTracker.xcodeproj \
  -scheme StockPriceTracker \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UDID'

# Separately: transport tests, excluding the external-server suite
cd Packages/WebSocketTransport
xcodebuild test -scheme WebSocketTransport \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' \
  -skip-testing:WebSocketTransportTests/WebSocketEchoIntegrationTests
```

## Regional support and remaining work

The string catalog includes Arabic translations. Currency and date formatting use locale-aware format styles; the simulated instruments are denominated in USD. Generated stock descriptions are still English placeholders. Arabic layout, accessibility, and navigation need device-level verification.

Before submission, validate a fresh clone, run the package suite and live echo check, add CI, and confirm a public GitHub repository URL. Further hardening includes failure/retry coverage, an explicit background/foreground policy, and bounded handling of stalled connections. The app currently retries manually and retains per-message debug logging. No automated UI tests are included.

## Source control

Keep each behavior change and its tests in a focused commit. Run the affected checks before committing, and keep personal Xcode state out of submissions. Review changes through pull requests when collaborating. The public repository URL should be provided separately with the assessment submission.
