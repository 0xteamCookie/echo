/// P2-7 — on-device SOS triage.
///
/// When the device is offline and the user fires an SOS, we want a tiny bit
/// of structured metadata (category + severity + short summary) attached to
/// the packet so rescuers reading the mesh (and the admin dashboard, once
/// the packet eventually syncs) can triage quickly without waiting for the
/// backend Gemini call.
///
/// Ideal: Android AICore / on-device Gemini Nano via the `firebase_ai`
/// bridge. As of Nov 2025 that bridge is still preview-only on Android and
/// isn't reliably available from a Flutter dart:io build. We therefore
/// implement a zero-dependency keyword classifier as a deterministic
/// fallback that always produces a valid JSON blob. The classifier hits the
/// same packet field (`meta.triage`) the admin UI reads, so the P2-7 pill
/// still lights up even when the preview model path is unavailable.
///
/// TODO(P2-7): once `firebase_ai` stabilises on-device inference in Flutter,
/// swap `_classifyWithKeywords` for a `FirebaseAI.onDeviceModel()` call and
/// tag the result with `source: 'gemini-nano'`. Keep the keyword classifier
/// as a hard fallback so an offline device with no model binary still works.
library;

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Shape mirrored on the admin side (`reports` table → `meta.triage`).
class TriageResult {
  final String source; // 'on-device-keyword' | 'gemini-nano' (future)
  final List<String> categories; // e.g. ['medical']
  final String severity; // 'low' | 'medium' | 'high' | 'critical'
  final String summary; // ≤ 80 chars

  const TriageResult({
    required this.source,
    required this.categories,
    required this.severity,
    required this.summary,
  });

  /// Compact JSON suitable for embedding inside the `triage` packet field.
  /// Deliberately short — BLE MTU is tight.
  String toJsonString() => jsonEncode({
        's': source,
        'c': categories,
        'sv': severity,
        'su': summary,
      });
}

/// Triage [message]. Returns `null` if triage should be skipped (device is
/// online → let the backend do the heavy lifting, or the call exceeded the
/// 500 ms budget).
///
/// Always short-circuits on timeout so the SOS fast-path never blocks on
/// this. The caller should treat `null` as "send packet as-is".
Future<TriageResult?> triageSosMessage(
  String message, {
  Duration timeout = const Duration(milliseconds: 500),
}) async {
  try {
    final result = await _triageImpl(message).timeout(timeout);
    return result;
  } on TimeoutException {
    return null;
  } catch (_) {
    return null;
  }
}

Future<TriageResult?> _triageImpl(String message) async {
  // Only triage on-device when we actually need to — if the device has
  // connectivity, the backend will do a richer Gemini pass during ingest.
  final online = await _isOnline();
  if (online) return null;

  return _classifyWithKeywords(message);
}

Future<bool> _isOnline() async {
  try {
    final res = await Connectivity().checkConnectivity();
    return !res.contains(ConnectivityResult.none);
  } catch (_) {
    return false;
  }
}

// ─── Keyword classifier (deterministic fallback) ────────────────────────────
//
// Intentionally crude; designed purely to produce a useful enough
// `meta.triage` blob for the admin UI until the real on-device Gemini Nano
// bridge lands. Patterns are additive: a single message can hit multiple
// categories (e.g. "fire and injuries").

const Map<String, List<String>> _categoryKeywords = {
  'medical': [
    'injur', 'bleed', 'blood', 'wound', 'broken', 'fractur', 'heart',
    'chest pain', 'unconscious', 'breath', 'choke', 'cpr', 'medic',
    'hospital', 'ambulance', 'hurt', 'pain',
  ],
  'fire': [
    'fire', 'burn', 'smoke', 'flame', 'blaze', 'gas leak',
  ],
  'trapped': [
    'trapped', 'stuck', 'collaps', 'rubble', 'debris', 'buried', 'pinned',
  ],
  'flood': [
    'flood', 'water', 'drown', 'submerged', 'rising water',
  ],
  'structural': [
    'building', 'wall', 'roof', 'ceiling', 'floor', 'bridge',
    'collaps', 'crack', 'leaning',
  ],
  'security': [
    'shoot', 'shot', 'gun', 'attack', 'assault', 'weapon', 'violen',
  ],
  'fall': [
    'fall', 'fell', 'fallen',
  ],
};

const Map<String, List<String>> _severityKeywords = {
  'critical': [
    'dying', 'unconscious', 'not breath', 'no pulse', 'severe bleed',
    'heart attack', 'cardiac', 'trapped', 'buried', 'drown',
  ],
  'high': [
    'bleed', 'heavy', 'serious', 'severe', 'urgent', 'asap', 'now',
    'fracture', 'broken', 'gas leak', 'fire',
  ],
  'medium': [
    'injur', 'hurt', 'pain', 'help', 'need', 'stuck',
  ],
};

TriageResult _classifyWithKeywords(String raw) {
  final lower = raw.toLowerCase();

  // Strip the department prefix added by send-heartbeat (`[MEDICAL] ...`) so
  // the classifier focuses on the user-authored body, and use the prefix as
  // a strong category hint.
  String body = lower;
  final catHints = <String>[];
  final prefixMatch = RegExp(r'^\s*\[([a-z ]+)\]\s*').firstMatch(lower);
  if (prefixMatch != null) {
    final dept = prefixMatch.group(1)!.trim();
    if (dept.contains('medic')) catHints.add('medical');
    if (dept.contains('fire')) catHints.add('fire');
    if (dept.contains('rescue')) catHints.add('trapped');
    if (dept.contains('police')) catHints.add('security');
    body = lower.substring(prefixMatch.end);
  }

  final categories = <String>{...catHints};
  for (final entry in _categoryKeywords.entries) {
    for (final kw in entry.value) {
      if (body.contains(kw)) {
        categories.add(entry.key);
        break;
      }
    }
  }
  if (categories.isEmpty) categories.add('general');

  String severity = 'low';
  severityLoop:
  for (final level in ['critical', 'high', 'medium']) {
    for (final kw in _severityKeywords[level]!) {
      if (body.contains(kw)) {
        severity = level;
        break severityLoop;
      }
    }
  }
  // Any medical/fire/trapped/flood → bump floor to medium.
  if (severity == 'low' &&
      (categories.contains('medical') ||
          categories.contains('fire') ||
          categories.contains('trapped') ||
          categories.contains('flood'))) {
    severity = 'medium';
  }

  final summary = _summarise(raw);

  return TriageResult(
    source: 'on-device-keyword',
    categories: categories.toList()..sort(),
    severity: severity,
    summary: summary,
  );
}

String _summarise(String raw) {
  final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (trimmed.length <= 80) return trimmed;
  return '${trimmed.substring(0, 77)}...';
}
