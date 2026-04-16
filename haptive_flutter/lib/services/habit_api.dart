import 'dart:convert';

import 'package:http/http.dart' as http;

import '../state/habit_store.dart';

/// Optional sync with the FastAPI backend (`backend/main.py`).
class HabitApi {
  HabitApi({this.baseUrl = 'http://127.0.0.1:8000'});

  final String baseUrl;

  Uri _u(String path) => Uri.parse('$baseUrl$path');
  Map<String, String> _identityQuery(HabitStore store) => {
        'device_id': store.deviceId,
        'display_name': store.displayName,
      };
  Map<String, String> _identityQueryWithVersion(HabitStore store) => {
        ..._identityQuery(store),
        'if_version': store.version.toString(),
      };

  void _syncStart(HabitStore store) {
    store.setSyncIndicator(syncing: true, message: 'Syncing...');
  }

  void _syncSuccess(HabitStore store, {String message = 'Synced'}) {
    store.setSyncIndicator(syncing: false, message: message, markSynced: true);
    if (message == 'Synced after retry') {
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (store.isSyncing) return;
        if (store.syncStatusMessage != 'Synced after retry') return;
        store.setSyncIndicator(syncing: false, message: 'Synced');
      });
    }
  }

  void _syncFailure(HabitStore store, {String message = 'Sync failed'}) {
    store.setSyncIndicator(syncing: false, message: message);
  }

  Future<void> applyRemoteState(HabitStore store) async {
    _syncStart(store);
    final res = await http.get(
      _u('/habit/state').replace(queryParameters: _identityQuery(store)),
    );
    if (res.statusCode != 200) {
      _syncFailure(store);
      return;
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    // Do not apply last_relapse_date from GET — server seed rows used to reset the
    // streak to a fixed "2 days ago". Local persistence is source of truth; POST
    // endpoints still return full state and update last relapse when needed.
    data.remove('last_relapse_date');
    store.replaceFromJson(data);
    _syncSuccess(store);
  }

  Future<void> postResist(HabitStore store) async {
    _syncStart(store);
    final res = await http.post(
      _u('/habit/resist').replace(queryParameters: _identityQueryWithVersion(store)),
    );
    if (res.statusCode == 409) {
      await applyRemoteState(store);
      final retry = await http.post(
        _u('/habit/resist').replace(queryParameters: _identityQueryWithVersion(store)),
      );
      if (retry.statusCode != 200) {
        _syncFailure(store);
        return;
      }
      final data = jsonDecode(retry.body) as Map<String, dynamic>;
      store.replaceFromJson(data);
      _syncSuccess(store, message: 'Synced after retry');
      return;
    }
    if (res.statusCode != 200) {
      _syncFailure(store);
      return;
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    store.replaceFromJson(data);
    _syncSuccess(store);
  }

  Future<void> postTrigger(HabitStore store, String emotion) async {
    _syncStart(store);
    final res = await http.post(
      _u('/habit/log-trigger').replace(queryParameters: _identityQueryWithVersion(store)),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'emotion': emotion}),
    );
    if (res.statusCode == 409) {
      await applyRemoteState(store);
      final retry = await http.post(
        _u('/habit/log-trigger').replace(queryParameters: _identityQueryWithVersion(store)),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'emotion': emotion}),
      );
      if (retry.statusCode != 200) {
        _syncFailure(store);
        return;
      }
      final data = jsonDecode(retry.body) as Map<String, dynamic>;
      store.replaceFromJson(data);
      _syncSuccess(store, message: 'Synced after retry');
      return;
    }
    if (res.statusCode != 200) {
      _syncFailure(store);
      return;
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    store.replaceFromJson(data);
    _syncSuccess(store);
  }

  Future<void> postRelapse(HabitStore store, {DateTime? at}) async {
    _syncStart(store);
    final body = at != null
        ? jsonEncode({'at': at.toUtc().toIso8601String()})
        : jsonEncode(<String, dynamic>{});
    final res = await http.post(
      _u('/habit/relapse').replace(queryParameters: _identityQueryWithVersion(store)),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    if (res.statusCode == 409) {
      await applyRemoteState(store);
      final retry = await http.post(
        _u('/habit/relapse').replace(queryParameters: _identityQueryWithVersion(store)),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      if (retry.statusCode != 200) {
        _syncFailure(store);
        return;
      }
      final data = jsonDecode(retry.body) as Map<String, dynamic>;
      store.replaceFromJson(data);
      _syncSuccess(store, message: 'Synced after retry');
      return;
    }
    if (res.statusCode != 200) {
      _syncFailure(store);
      return;
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    store.replaceFromJson(data);
    _syncSuccess(store);
  }

  Future<void> postPreferences(
    HabitStore store, {
    required double dailySpend,
    required double dailyHours,
    bool? onboardingCompleted,
    String? goalType,
    String? quitReason,
    List<String>? triggerProfile,
    int? milestoneDays,
    String? preferredCurrency,
  }) async {
    _syncStart(store);
    final body = <String, dynamic>{
      'daily_spend': dailySpend,
      'daily_hours': dailyHours,
    };
    if (onboardingCompleted != null) {
      body['onboarding_completed'] = onboardingCompleted;
    }
    if (goalType != null) body['goal_type'] = goalType;
    if (quitReason != null) body['quit_reason'] = quitReason;
    if (triggerProfile != null) body['trigger_profile'] = triggerProfile;
    if (milestoneDays != null) body['milestone_days'] = milestoneDays;
    if (preferredCurrency != null) {
      body['preferred_currency'] = preferredCurrency;
    }
    final res = await http.post(
      _u('/habit/preferences').replace(
        queryParameters: _identityQueryWithVersion(store),
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode == 409) {
      await applyRemoteState(store);
      final retry = await http.post(
        _u('/habit/preferences').replace(
          queryParameters: _identityQueryWithVersion(store),
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (retry.statusCode != 200) {
        _syncFailure(store);
        return;
      }
      final data = jsonDecode(retry.body) as Map<String, dynamic>;
      store.replaceFromJson(data);
      _syncSuccess(store, message: 'Synced after retry');
      return;
    }
    if (res.statusCode != 200) {
      _syncFailure(store);
      return;
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    store.replaceFromJson(data);
    _syncSuccess(store);
  }

  Future<Map<String, dynamic>?> getSummary(HabitStore store) async {
    final res = await http.get(
      _u('/habit/summary').replace(queryParameters: _identityQuery(store)),
    );
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body);
    return data is Map<String, dynamic> ? data : null;
  }

  Future<List<Map<String, dynamic>>?> getModes(HabitStore store) async {
    final res = await http.get(
      _u('/habit/modes').replace(queryParameters: _identityQuery(store)),
    );
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body);
    if (data is! List) return null;
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<int>?> getWeeklyActivity(HabitStore store) async {
    final res = await http.get(
      _u('/habit/weekly-activity').replace(queryParameters: _identityQuery(store)),
    );
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) return null;
    final mondayFirst = data['monday_first'];
    if (mondayFirst is! List || mondayFirst.length != 7) return null;
    return mondayFirst.map((e) => (e as num).toInt().clamp(0, 1000000)).toList();
  }

  Future<void> postCraveSession(
    HabitStore store, {
    required String mode,
    required bool helped,
  }) async {
    _syncStart(store);
    final payload = {
      'mode': mode,
      'helped': helped,
      'at': DateTime.now().toUtc().toIso8601String(),
    };
    final res = await http.post(
      _u('/habit/crave-session').replace(queryParameters: _identityQueryWithVersion(store)),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 409) {
      await applyRemoteState(store);
      final retry = await http.post(
        _u('/habit/crave-session').replace(queryParameters: _identityQueryWithVersion(store)),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (retry.statusCode != 200) {
        _syncFailure(store);
        return;
      }
      final data = jsonDecode(retry.body) as Map<String, dynamic>;
      store.replaceFromJson(data);
      _syncSuccess(store, message: 'Synced after retry');
      return;
    }
    if (res.statusCode != 200) {
      _syncFailure(store);
      return;
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    store.replaceFromJson(data);
    _syncSuccess(store);
  }
}
