import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _deviceIdKey = 'haptive_device_id_v1';
const _displayNameKey = 'haptive_display_name_v1';

class DeviceIdentity {
  const DeviceIdentity({required this.deviceId, required this.displayName});

  final String deviceId;
  final String displayName;
}

class DeviceIdentityService {
  static Future<DeviceIdentity> loadOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_deviceIdKey);
    final savedName = prefs.getString(_displayNameKey);
    if (savedId != null &&
        savedId.isNotEmpty &&
        savedName != null &&
        savedName.isNotEmpty) {
      // On web/dev, older builds could save random anon_* ids.
      // Regenerate a deterministic id so name stays stable across restarts.
      if (kIsWeb && savedId.startsWith('anon_')) {
        final webId = await _readPlatformDeviceId();
        if (webId != null && webId.isNotEmpty) {
          final upgraded = _nameFromDeviceId(webId);
          await prefs.setString(_deviceIdKey, webId);
          await prefs.setString(_displayNameKey, upgraded);
          return DeviceIdentity(deviceId: webId, displayName: upgraded);
        }
      }
      // Backfill older two-word names to unique hash-suffixed format.
      if (!savedName.contains('#')) {
        final upgraded = _nameFromDeviceId(savedId);
        await prefs.setString(_displayNameKey, upgraded);
        return DeviceIdentity(deviceId: savedId, displayName: upgraded);
      }
      return DeviceIdentity(deviceId: savedId, displayName: savedName);
    }

    final deviceId = await _readPlatformDeviceId() ?? _randomFallbackId();
    final displayName = _nameFromDeviceId(deviceId);
    await prefs.setString(_deviceIdKey, deviceId);
    await prefs.setString(_displayNameKey, displayName);
    return DeviceIdentity(deviceId: deviceId, displayName: displayName);
  }

  static Future<String?> _readPlatformDeviceId() async {
    final info = DeviceInfoPlugin();
    if (kIsWeb) {
      try {
        final data = await info.webBrowserInfo;
        final parts = <String>[
          data.browserName.name,
          data.platform ?? '',
          data.vendor ?? '',
          data.userAgent ?? '',
          '${data.hardwareConcurrency ?? 0}',
          '${data.maxTouchPoints ?? 0}',
          '${data.deviceMemory ?? 0}',
        ];
        final raw = parts.join('|');
        return 'web_${_fnv1a32(raw).toRadixString(16)}';
      } catch (_) {
        // Deterministic fallback for web: never use random here.
        final raw = '${Uri.base.scheme}|${Uri.base.host}|haptive-web';
        return 'web_${_fnv1a32(raw).toRadixString(16)}';
      }
    }
    try {
      if (Platform.isAndroid) {
        final data = await info.androidInfo;
        return data.id.isNotEmpty ? 'android_${data.id}' : null;
      }
      if (Platform.isIOS) {
        final data = await info.iosInfo;
        final v = data.identifierForVendor;
        return v != null && v.isNotEmpty ? 'ios_$v' : null;
      }
      if (Platform.isWindows) {
        final data = await info.windowsInfo;
        return data.deviceId.isNotEmpty ? 'win_${data.deviceId}' : null;
      }
      if (Platform.isMacOS) {
        final data = await info.macOsInfo;
        final guid = data.systemGUID;
        return guid != null && guid.isNotEmpty ? 'mac_$guid' : null;
      }
      if (Platform.isLinux) {
        final data = await info.linuxInfo;
        return data.machineId?.isNotEmpty == true ? 'linux_${data.machineId}' : null;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static String _randomFallbackId() {
    // Web-safe bounds: avoid bit-shifts like (1 << 32), which overflow on JS runtimes.
    final r = Random();
    const max31 = 0x7fffffff;
    final a = r.nextInt(max31).toRadixString(16).padLeft(8, '0');
    final b = r.nextInt(max31).toRadixString(16).padLeft(8, '0');
    return 'anon_${DateTime.now().microsecondsSinceEpoch}_$a$b';
  }

  static String _nameFromDeviceId(String id) {
    const left = [
      'Steady',
      'Calm',
      'Focused',
      'Bold',
      'Bright',
      'Grounded',
      'Resilient',
      'Patient',
      'Clear',
      'Brave',
    ];
    const right = [
      'Falcon',
      'River',
      'Pine',
      'Summit',
      'Harbor',
      'Atlas',
      'Nova',
      'Comet',
      'Oak',
      'Dawn',
    ];
    final hash = _fnv1a32(id);
    final first = left[hash % left.length];
    final second = right[(hash ~/ left.length) % right.length];
    final suffix = hash.toRadixString(16).padLeft(8, '0').substring(0, 4).toUpperCase();
    return '$first $second #$suffix';
  }

  static int _fnv1a32(String input) {
    var hash = 0x811c9dc5;
    for (final c in input.codeUnits) {
      hash ^= c;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}
