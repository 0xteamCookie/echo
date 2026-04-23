/// Single source of truth for all application-wide constants.
///
/// Import via:
///   import 'package:echo/core/constants.dart';
library;

// ─── BLE / Mesh UUIDs ────────────────────────────────────────────────────────
/// GATT service UUID advertised by every Beacon device.
/// Must match across central (scanner) and peripheral (advertiser).
const String kServiceUuid = '12345678-1234-5678-1234-56789abcdef0';

/// GATT characteristic UUID used to exchange raw mesh packets via GATT Write.
const String kCharacteristicUuid = '12345678-1234-5678-1234-56789abcdefF';

// ─── Mesh / Relay protocol ───────────────────────────────────────────────────
/// How often the relay loop re-broadcasts eligible stored packets.
const Duration kRelayInterval = Duration(seconds: 15);

/// How long a generated packet stays alive in the mesh before it expires.
const Duration kMessageLifespan = Duration(days: 1);

/// Maximum hop count before a packet is silently dropped (prevents loops).
/// Must match [maxHops] in packet_codec.dart.
const int kMaxHops = 8;

/// How long a device stays in the "seen" map after its last scan result.
/// Devices not seen within this window are pruned so the relay list stays fresh.
const Duration kSeenDeviceTtl = Duration(minutes: 5);

// ─── SharedPreferences keys ──────────────────────────────────────────────────
/// Persisted stable device identity (UUID generated once on first launch).
const String kPrefDeviceId = 'ble_mesh_device_id';

/// Display name shown in outbound mesh packets.
const String kPrefUserName = 'user_name';

/// Whether the accelerometer-based fall-detection auto-SOS is enabled.
const String kPrefAutoSosEnabled = 'auto_sos_enabled';

// ─── Geography ───────────────────────────────────────────────────────────────
/// WGS-84 mean Earth radius in metres.
/// Used by every haversine calculation in the app.
const double kEarthRadiusMetres = 6371000.0;

/// Heatmap grid cell size in degrees latitude (~50 m; 1° lat ≈ 111 km).
const double kHeatmapCellDegLat = 50.0 / 111000.0;

// ─── Map tiles ───────────────────────────────────────────────────────────────
/// OpenStreetMap tile URL template used by flutter_map and the offline downloader.
const String kOsmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Zoom range for a detailed offline tile download (small area, high detail).
const int kOfflineZoomDetailedMin = 13;
const int kOfflineZoomDetailedMax = 17;

/// Zoom range for a low-resolution offline tile download (large area, less detail).
const int kOfflineZoomLowResMin = 10;
const int kOfflineZoomLowResMax = 13;

// ─── Fall detection thresholds ───────────────────────────────────────────────
/// G-force spike threshold that triggers the fall-detection window.
const double kFallGSpikeThreshold = 3.0; // multiples of standard gravity

/// Standard gravity (m/s²).
const double kStandardGravity = 9.80665;

/// ±band around gravity within which the device is considered "still" (m/s²).
const double kStillnessBand = 0.30 * kStandardGravity;

/// Time window after a g-spike in which immobility must begin.
const Duration kFallSpikeWindow = Duration(seconds: 10);

/// How long immobility must persist to confirm a fall event.
const Duration kFallImmobilityRequired = Duration(minutes: 2);

/// Duration of the cancellable countdown before an auto-SOS is sent.
const Duration kFallCountdownDuration = Duration(seconds: 30);

// ─── Heatmap UI ──────────────────────────────────────────────────────────────
/// How often the heatmap screen auto-refreshes from the local DB.
const Duration kHeatmapRefreshInterval = Duration(seconds: 30);
