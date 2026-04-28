library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

const _kAutoSosEnabledKey = kPrefAutoSosEnabled;

const double _gSpikeThreshold = kFallGSpikeThreshold;
const double _gravity = kStandardGravity;
const double _stillnessBand = kStillnessBand;
const Duration _spikeWindow = kFallSpikeWindow;
const Duration _immobilityRequired = kFallImmobilityRequired;
const Duration _countdownDuration = kFallCountdownDuration;

typedef FallWarningHandler =
    void Function({
      required Duration countdown,
      required VoidCallback onCancel,
      required VoidCallback onConfirm,
    });

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
      _accelSub =
          userAccelerometerEventStream(
            samplingPeriod: const Duration(milliseconds: 100),
          ).listen(
            _onAccel,
            onError: (Object e, _) {
              debugPrint('[ActivityMonitor] accel stream error: $e');
            },
          );
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
    final magG = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z) / _gravity;
    final now = DateTime.now();

    if (magG > _gSpikeThreshold) {
      _lastSpikeAt = now;
      _immobilitySince = null;
      debugPrint('[ActivityMonitor] g-spike ${magG.toStringAsFixed(2)}g');
      return;
    }

    if (_lastSpikeAt == null) return;
    if (now.difference(_lastSpikeAt!) > _spikeWindow + _immobilityRequired) {
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
    trigger(
      'Auto-SOS: possible fall detected. No response from user.',
    ).catchError((Object e, _) {
      debugPrint('[ActivityMonitor] auto-SOS failed: $e');
    });
  }
}
