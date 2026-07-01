library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../main.dart' show rootNavigatorKey, BeaconColors;

/// Checks the mesh prerequisites (BT + Location permissions, BT on, Location on)
/// and prompts the user to fix any that are off. Android returns zero BLE scan
/// results if Location is off, even with permissions granted.
class MeshReadiness {
  MeshReadiness._();
  static final MeshReadiness instance = MeshReadiness._();

  /// True when all mesh prerequisites are satisfied (UI watches this).
  final ValueNotifier<bool> isReady = ValueNotifier<bool>(false);

  /// Human-readable reason the mesh isn't ready (empty when ready).
  final ValueNotifier<String> blocker = ValueNotifier<String>('');

  bool _prompting = false;

  BuildContext? get _ctx => rootNavigatorKey.currentContext;

  /// Runs the full readiness sequence, prompting for anything missing.
  /// Returns true once everything is satisfied.
  Future<bool> ensureReady() async {
    if (_prompting) return isReady.value;
    _prompting = true;
    try {
      // 1) Runtime permissions (Bluetooth + Location).
      final permsOk = await _ensurePermissions();
      if (!permsOk) {
        _setBlocked('Bluetooth & Location permissions are required for the mesh.');
        await _showFixDialog(
          title: 'Permissions needed',
          message:
              'Echo needs Bluetooth and Location permissions to relay messages '
              'to nearby phones. Please allow them in Settings.',
          actionLabel: 'Open Settings',
          onAction: openAppSettings,
        );
        return false;
      }

      // 2) Bluetooth adapter ON (Android can show the system enable dialog).
      final btOk = await _ensureBluetoothOn();
      if (!btOk) {
        _setBlocked('Bluetooth is off. Turn it on to use the mesh.');
        await _showFixDialog(
          title: 'Turn on Bluetooth',
          message:
              'The mesh relays messages over Bluetooth. Please switch Bluetooth '
              'on to connect with nearby phones.',
          actionLabel: 'Enable Bluetooth',
          onAction: () async {
            try {
              await FlutterBluePlus.turnOn();
            } catch (_) {}
          },
        );
        return false;
      }

      // 3) Location (GPS) master toggle ON — required for BLE scanning.
      final locOk = await Geolocator.isLocationServiceEnabled();
      if (!locOk) {
        _setBlocked('Location is off. Android needs it on to find nearby phones.');
        await _showFixDialog(
          title: 'Turn on Location',
          message:
              'Android requires Location to be ON for Bluetooth scanning — '
              'without it, Echo cannot discover nearby phones. Your location is '
              'never shared just for scanning.',
          actionLabel: 'Open Location Settings',
          onAction: () async {
            try {
              await Geolocator.openLocationSettings();
            } catch (_) {}
          },
        );
        return false;
      }

      _setReady();
      return true;
    } finally {
      _prompting = false;
    }
  }

  /// Lightweight re-check with no prompts (for app-resume). Updates [isReady].
  Future<bool> refresh() async {
    final perms = await _permissionsGranted();
    final bt = FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;
    final loc = await Geolocator.isLocationServiceEnabled();
    final ok = perms && bt && loc;
    if (ok) {
      _setReady();
    } else {
      _setBlocked(
        !perms
            ? 'Bluetooth & Location permissions are required.'
            : !bt
                ? 'Bluetooth is off.'
                : 'Location is off (needed for Bluetooth scanning).',
      );
    }
    return ok;
  }

  // ─── internals ────────────────────────────────────────────────────────────

  Future<bool> _permissionsGranted() async {
    final statuses = await Future.wait([
      Permission.bluetoothScan.status,
      Permission.bluetoothConnect.status,
      Permission.bluetoothAdvertise.status,
      Permission.locationWhenInUse.status,
    ]);
    return statuses.every((s) => s.isGranted || s.isLimited);
  }

  Future<bool> _ensurePermissions() async {
    if (await _permissionsGranted()) return true;
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ].request();
    return _permissionsGranted();
  }

  Future<bool> _ensureBluetoothOn() async {
    if (FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on) return true;
    try {
      await FlutterBluePlus.turnOn(); // Android: shows system enable dialog.
    } catch (_) {}
    try {
      final state = await FlutterBluePlus.adapterState
          .firstWhere((s) => s == BluetoothAdapterState.on)
          .timeout(const Duration(seconds: 8));
      return state == BluetoothAdapterState.on;
    } catch (_) {
      return FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;
    }
  }

  void _setReady() {
    blocker.value = '';
    isReady.value = true;
  }

  void _setBlocked(String reason) {
    blocker.value = reason;
    isReady.value = false;
  }

  Future<void> _showFixDialog({
    required String title,
    required String message,
    required String actionLabel,
    required Future<void> Function() onAction,
  }) async {
    final ctx = _ctx;
    if (ctx == null) return;
    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (dctx) => AlertDialog(
        icon: const Icon(Icons.wifi_tethering_rounded,
            color: BeaconColors.primary, size: 36),
        title: Text(title),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dctx).pop();
              await onAction();
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
