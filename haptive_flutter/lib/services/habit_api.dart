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

  Future<void> applyRemoteState(HabitStore store) async {
    final res = await http.get(
      _u('/habit/state').replace(queryParameters: _identityQuery(store)),
    );
    if (res.statusCode != 200) return;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    // Do not apply last_relapse_date from GET — server seed rows used to reset the
    // streak to a fixed "2 days ago". Local persistence is source of truth; POST
    // endpoints still return full state and update last relapse when needed.
    data.remove('last_relapse_date');
    store.replaceFromJson(data);
  }

  Future<void> postResist(HabitStore store) async {
    final res = await http.post(
      _u('/habit/resist').replace(queryParameters: _identityQuery(store)),
    );
    if (res.statusCode != 200) return;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    store.replaceFromJson(data);
  }

  Future<void> postTrigger(HabitStore store, String emotion) async {
    final res = await http.post(
      _u('/habit/log-trigger').replace(queryParameters: _identityQuery(store)),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'emotion': emotion}),
    );
    if (res.statusCode != 200) return;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    store.replaceFromJson(data);
  }

  Future<void> postRelapse(HabitStore store, {DateTime? at}) async {
    final body = at != null
        ? jsonEncode({'at': at.toUtc().toIso8601String()})
        : jsonEncode(<String, dynamic>{});
    final res = await http.post(
      _u('/habit/relapse').replace(queryParameters: _identityQuery(store)),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    if (res.statusCode != 200) return;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    store.replaceFromJson(data);
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
        queryParameters: {
          ..._identityQuery(store),
          'if_version': store.version.toString(),
        },
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) return;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    store.replaceFromJson(data);
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
    final res = await http.post(
      _u('/habit/crave-session').replace(queryParameters: _identityQuery(store)),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'mode': mode,
        'helped': helped,
        'at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    if (res.statusCode != 200) return;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    store.replaceFromJson(data);
  }
}
