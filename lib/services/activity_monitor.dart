/// P2-15 — accelerometer-based fall/immobility detector with auto-SOS.
///
/// Pure `sensors_plus` — no activity-recognition SDK, so we stay off Google
/// Play Services and this works equally on Android and iOS. The detector
/// fires a "fall detected" event when:
///
///   1. A g-spike > 3 g is observed, followed by
///   2. Sustained immobility (accel magnitude stays within ±0.3 g of gravity
///      for > 2 minutes).
///
/// When that combination fires we pop a 30 s countdown. If the user taps
/// "I'm OK" the countdown is cancelled. Otherwise we auto-send an SOS with
/// `isSos=1` and a canned message.
///
/// Opt-in via SharedPreferences flag `auto_sos_enabled`. Off by default.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAutoSosEnabledKey = 'auto_sos_enabled';

const double _gSpikeThreshold = 3.0; // multiples of g
const double _gravity = 9.80665;
const double _stillnessBand = 0.30 * _gravity; // ±0.3 g around gravity
const Duration _spikeWindow = Duration(seconds: 10);
const Duration _immobilityRequired = Duration(minutes: 2);
const Duration _countdownDuration = Duration(seconds: 30);

/// Callback used by the UI to surface the 30-second cancellable countdown.
/// [onCancel] cancels the pending auto-SOS; [onConfirm] skips the countdown
/// and sends immediately. Implementations should show a modal/banner.
typedef FallWarningHandler = void Function({
  required Duration countdown,
  required VoidCallback onCancel,
  required VoidCallback onConfirm,
});

/// Called when the countdown elapses without a cancel → fire the SOS. The
/// implementation is wired to `sendSosHeartbeat` from `send_heartbeat.dart`
/// in `main.dart`.
typedef AutoSosTrigger = Future<void> Function(String message);

class ActivityMonitor {
  ActivityMonitor._();
  static final ActivityMonitor instance = ActivityMonitor._();

  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  DateTime? _lastSpikeAt;
  DateTime? _immobilitySince;
  Timer? _countdownTimer;
  bool _warningActive = false;

  FallWarningHandler? _warningHandler;
  AutoSosTrigger? _sosTrigger;

  /// Persistent opt-in. When false, [start] is a no-op.
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAutoSosEnabledKey) ?? false;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoSosEnabledKey, enabled);
    if (enabled) {
      await instance.start();
    } else {
      await instance.stop();
    }
  }

  /// Install UI + SOS hooks. Safe to call multiple times; latest wins.
  void installHooks({
    FallWarningHandler? warningHandler,
    AutoSosTrigger? sosTrigger,
  }) {
    _warningHandler = warningHandler ?? _warningHandler;
    _sosTrigger = sosTrigger ?? _sosTrigger;
  }

  Future<void> start() async {
    if (!await isEnabled()) return;
    if (_accelSub != null) return;

    try {
      _accelSub = userAccelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 100),
      ).listen(_onAccel, onError: (Object e, _) {
        debugPrint('[ActivityMonitor] accel stream error: $e');
      });
      debugPrint('[ActivityMonitor] started');
    } catch (e) {
      debugPrint('[ActivityMonitor] start failed: $e');
    }
  }

  Future<void> stop() async {
    await _accelSub?.cancel();
    _accelSub = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _lastSpikeAt = null;
    _immobilitySince = null;
    _warningActive = false;
    debugPrint('[ActivityMonitor] stopped');
  }

  void _onAccel(UserAccelerometerEvent e) {
    // `userAccelerometerEventStream` already subtracts gravity, so a
    // stationary device reports ~0,0,0. A fall registers as a transient
    // impulse whose magnitude crosses several g.
    final magG = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z) / _gravity;
    final now = DateTime.now();

    if (magG > _gSpikeThreshold) {
      _lastSpikeAt = now;
      _immobilitySince = null;
      debugPrint('[ActivityMonitor] g-spike ${magG.toStringAsFixed(2)}g');
      return;
    }

    // Only start the stillness clock within the spike window.
    if (_lastSpikeAt == null) return;
    if (now.difference(_lastSpikeAt!) > _spikeWindow + _immobilityRequired) {
      // Spike + grace window is ancient; reset.
      _lastSpikeAt = null;
      _immobilitySince = null;
      return;
    }

    final absAccel = magG * _gravity;
    if (absAccel < _stillnessBand) {
      _immobilitySince ??= now;
      if (now.difference(_immobilitySince!) >= _immobilityRequired &&
          !_warningActive) {
        _triggerWarning();
      }
    } else {
      _immobilitySince = null;
    }
  }

  void _triggerWarning() {
    _warningActive = true;
    debugPrint('[ActivityMonitor] fall suspected — starting 30 s countdown');

    final handler = _warningHandler;
    if (handler != null) {
      handler(
        countdown: _countdownDuration,
        onCancel: _cancelCountdown,
        onConfirm: _fireAutoSosNow,
      );
    }

    _countdownTimer = Timer(_countdownDuration, _fireAutoSosNow);
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _warningActive = false;
    _lastSpikeAt = null;
    _immobilitySince = null;
    debugPrint('[ActivityMonitor] countdown cancelled by user');
  }

  void _fireAutoSosNow() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _warningActive = false;
    _lastSpikeAt = null;
    _immobilitySince = null;

    final trigger = _sosTrigger;
    if (trigger == null) {
      debugPrint('[ActivityMonitor] no SOS trigger wired — skipping auto-SOS');
      return;
    }
    trigger('Auto-SOS: possible fall detected. No response from user.')
        .catchError((Object e, _) {
      debugPrint('[ActivityMonitor] auto-SOS failed: $e');
    });
  }
}
