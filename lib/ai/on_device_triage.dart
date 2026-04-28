library;

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';

class TriageResult {
  final String source;
  final List<String> categories;
  final String severity;
  final String summary;

  const TriageResult({
    required this.source,
    required this.categories,
    required this.severity,
    required this.summary,
  });

  String toJsonString() =>
      jsonEncode({'s': source, 'c': categories, 'sv': severity, 'su': summary});
}

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

const Map<String, List<String>> _categoryKeywords = {
  'medical': [
    'injur',
    'bleed',
    'blood',
    'wound',
    'broken',
    'fractur',
    'heart',
    'chest pain',
    'unconscious',
    'breath',
    'choke',
    'cpr',
    'medic',
    'hospital',
    'ambulance',
    'hurt',
    'pain',
  ],
  'fire': ['fire', 'burn', 'smoke', 'flame', 'blaze', 'gas leak'],
  'trapped': [
    'trapped',
    'stuck',
    'collaps',
    'rubble',
    'debris',
    'buried',
    'pinned',
  ],
  'flood': ['flood', 'water', 'drown', 'submerged', 'rising water'],
  'structural': [
    'building',
    'wall',
    'roof',
    'ceiling',
    'floor',
    'bridge',
    'collaps',
    'crack',
    'leaning',
  ],
  'security': ['shoot', 'shot', 'gun', 'attack', 'assault', 'weapon', 'violen'],
  'fall': ['fall', 'fell', 'fallen'],
};

const Map<String, List<String>> _severityKeywords = {
  'critical': [
    'dying',
    'unconscious',
    'not breath',
    'no pulse',
    'severe bleed',
    'heart attack',
    'cardiac',
    'trapped',
    'buried',
    'drown',
  ],
  'high': [
    'bleed',
    'heavy',
    'serious',
    'severe',
    'urgent',
    'asap',
    'now',
    'fracture',
    'broken',
    'gas leak',
    'fire',
  ],
  'medium': ['injur', 'hurt', 'pain', 'help', 'need', 'stuck'],
};

TriageResult _classifyWithKeywords(String raw) {
  final lower = raw.toLowerCase();

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
