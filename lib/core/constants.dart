/// Single source of truth for all application-wide constants.
///
/// Import via:
///   import 'package:echo/core/constants.dart';
library;

// BLE / Mesh UUIDs 
const String kServiceUuid = '12345678-1234-5678-1234-56789abcdef0';

/// GATT characteristic UUID
const String kCharacteristicUuid = '12345678-1234-5678-1234-56789abcdefF';

// Mesh / Relay protocol
const Duration kRelayInterval = Duration(seconds: 15);

const Duration kMessageLifespan = Duration(days: 1);

const int kMaxHops = 8;

const Duration kSeenDeviceTtl = Duration(minutes: 5);

// SharedPreferences keys
const String kPrefDeviceId = 'ble_mesh_device_id';

const String kPrefHasCompletedOnboarding = 'has_completed_onboarding';

const String kPrefUserName = 'user_name';

const String kPrefAutoSosEnabled = 'auto_sos_enabled';

// Geography
const double kEarthRadiusMetres = 6371000.0;

const double kHeatmapCellDegLat = 50.0 / 111000.0;

// Map tiles
const String kOsmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

const int kOfflineZoomDetailedMin = 13;
const int kOfflineZoomDetailedMax = 17;

const int kOfflineZoomLowResMin = 10;
const int kOfflineZoomLowResMax = 13;

// Fall detection thresholds
const double kFallGSpikeThreshold = 3.0; // multiples of standard gravity

/// Standard gravity (m/s²).
const double kStandardGravity = 9.80665;
const double kStillnessBand = 0.30 * kStandardGravity;
const Duration kFallSpikeWindow = Duration(seconds: 10);
const Duration kFallImmobilityRequired = Duration(minutes: 2);
const Duration kFallCountdownDuration = Duration(seconds: 30);

// Heatmap UI
const Duration kHeatmapRefreshInterval = Duration(seconds: 30);
