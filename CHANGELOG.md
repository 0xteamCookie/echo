# Changelog

All notable changes to **Echo** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Gemini Nano on-device triage via `firebase_ai` (currently waiting on Flutter SDK stability).
- iOS support (blocked on BLE peripheral parity).
- LoRa fallback transport for very-long-range deployments.

## [1.0.0] — 2026-04 — Solution Challenge 2026 prototype submission

### Added
- BLE-mesh chat & SOS over `flutter_blue_plus` (central) + `ble_peripheral` (peripheral).
- v3 wire format with Ed25519 signing; backward-compatible v1/v2 decoders.
- 15 s relay loop with RSSI-prioritized peer selection and 8-hop TTL.
- SOS fast-path (`MEDICAL` / `FIRE` / `POLICE` / `RESCUE`) bypassing the relay queue.
- On-device triage classifier (≤500 ms) emitting structured `{categories, severity, summary}`.
- Fall-detection auto-SOS via accelerometer state machine (3 g impact → 2 min stillness → 30 s cancellable countdown).
- Rescuer mode with QR-onboarded RS256 JWT and 2-minute on-duty heartbeats.
- Offline OSM map + 50 m-grid SOS heatmap.
- Auto-sync to backend on connectivity restoration.
- Authority announcements feed.
- Android foreground service for background mesh resilience.
- SQLite persistence with migration to schema v4 (`messages`, `message_devices`, signatures, triage, sync flags).

### Security
- Ed25519 device identity stored in `flutter_secure_storage`.
- RS256 rescuer-JWT verification with embedded admin public key.
- Bearer-token + Firebase App Check on backend ingest.
