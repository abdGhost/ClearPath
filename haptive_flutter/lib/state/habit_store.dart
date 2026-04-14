import 'package:flutter/foundation.dart';

class CraveSessionEntry {
  CraveSessionEntry({
    required this.mode,
    required this.helped,
    required this.at,
  });

  final String mode;
  final bool helped;
  final DateTime at;

  factory CraveSessionEntry.fromJson(Map<String, dynamic> json) {
    final atRaw = json['at'];
    return CraveSessionEntry(
      mode: (json['mode'] ?? 'unknown').toString(),
      helped: json['helped'] == true,
      at: atRaw is String ? (DateTime.tryParse(atRaw) ?? DateTime.now().toUtc()) : DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'helped': helped,
        'at': at.toUtc().toIso8601String(),
      };
}

/// App-wide habit state (Flutter analogue to a JS client store).
/// Sync with FastAPI via [HabitApi] when online.
class HabitStore extends ChangeNotifier {
  HabitStore({
    this.deviceId = '',
    this.displayName = '',
    this.onboardingCompleted = false,
    this.goalType = 'quit',
    this.quitReason = '',
    List<String>? triggerProfile,
    this.milestoneDays = 30,
    this.preferredCurrency = 'auto',
    this.dailySpend = 12.5,
    this.dailyHours = 1.5,
    this.version = 1,
    DateTime? lastRelapseDate,
    this.resistCount = 0,
    List<String>? triggerLog,
    List<int>? heatmapWeek,
    this.lastMoodLoggedAt,
    this.lastResistAt,
    List<CraveSessionEntry>? craveSessions,
  })  : lastRelapseDate = lastRelapseDate ?? DateTime.now(),
        triggerProfile = List<String>.from(triggerProfile ?? const []),
        _craveSessions = List<CraveSessionEntry>.from(craveSessions ?? const []),
        _triggerLog = List<String>.from(triggerLog ?? const []),
        _heatmapWeek = List<int>.from(
          heatmapWeek ?? const [0, 0, 0, 0, 0, 0, 0],
        );

  String deviceId;
  String displayName;
  bool onboardingCompleted;
  String goalType;
  String quitReason;
  List<String> triggerProfile;
  int milestoneDays;
  String preferredCurrency;
  double dailySpend;
  double dailyHours;
  int version;
  DateTime lastRelapseDate;
  int resistCount;
  DateTime? lastMoodLoggedAt;
  DateTime? lastResistAt;
  final List<CraveSessionEntry> _craveSessions;
  final List<String> _triggerLog;
  final List<int> _heatmapWeek;

  List<String> get triggerLog => List.unmodifiable(_triggerLog);
  List<int> get heatmapWeek => List.unmodifiable(_heatmapWeek);
  List<CraveSessionEntry> get craveSessions => List.unmodifiable(_craveSessions);

  Duration get cleanDuration => DateTime.now().difference(lastRelapseDate);

  int get cleanDays => cleanDuration.inDays;
  int get cleanHoursRemainder => cleanDuration.inHours % 24;

  /// Estimated money saved based on user-configured daily spend.
  double get moneySaved =>
      cleanDays * dailySpend + (cleanHoursRemainder / 24) * dailySpend;

  /// Estimated hours reclaimed based on user-configured daily time.
  double get timeReclaimedHours =>
      cleanDays * dailyHours + (cleanHoursRemainder / 24) * dailyHours;

  static const milestoneOptions = [7, 14, 30, 60, 90];

  void setDailyEstimates({required double spendPerDay, required double hoursPerDay}) {
    dailySpend = spendPerDay.clamp(0.0, 1000000.0);
    dailyHours = hoursPerDay.clamp(0.0, 24.0);
    notifyListeners();
  }

  void setPreferredCurrency(String preference) {
    preferredCurrency = _sanitizeCurrencyPreference(preference);
    notifyListeners();
  }

  /// Last Crave control / resist for Home (independent of mood).
  String? get lastResistSummary {
    final r = lastResistAt;
    if (r == null) return null;
    return '${_formatRelative(r)} · Resist';
  }

  /// Last mood / trigger tag for Home.
  String? get lastMoodSummary {
    final m = lastMoodLoggedAt;
    if (m == null) return null;
    return '${_formatRelative(m)} · Mood tag';
  }

  static String _formatRelative(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 45) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 14) return '${d.inDays}d ago';
    return '${(d.inDays / 7).floor()}w ago';
  }

  /// Counts trigger log lines, at most one category per entry (first match wins).
  Map<String, int> get triggerCategoryCounts {
    const keys = ['Stress', 'Boredom', 'Social'];
    final counts = {for (final k in keys) k: 0};
    for (final e in _triggerLog) {
      final lower = e.toLowerCase();
      for (final k in keys) {
        if (lower.contains(k.toLowerCase())) {
          counts[k] = counts[k]! + 1;
          break;
        }
      }
    }
    return counts;
  }

  /// Log lines that did not match Stress, Boredom, or Social.
  int get triggerUnmatchedCount {
    const keys = ['Stress', 'Boredom', 'Social'];
    var n = 0;
    for (final e in _triggerLog) {
      final lower = e.toLowerCase();
      final any = keys.any((k) => lower.contains(k.toLowerCase()));
      if (!any) n++;
    }
    return n;
  }

  /// Normalized 0–1 weights for charts (max category = 1). Empty log → equal placeholders.
  Map<String, double> get triggerRadar {
    final counts = triggerCategoryCounts;
    const keys = ['Stress', 'Boredom', 'Social'];
    final max = counts.values.fold<int>(0, (a, b) => a > b ? a : b);
    if (max == 0) {
      return {for (final k in keys) k: 0.35};
    }
    return {for (final e in counts.entries) e.key: e.value / max};
  }

  /// Mon = index 0 … Sun = index 6 (local time). From Crave session timestamps only.
  List<int> get weekdayCraveSessionCounts {
    final c = List<int>.filled(7, 0);
    for (final s in _craveSessions) {
      final i = s.at.toLocal().weekday - 1; // Mon=0 … Sun=6
      if (i >= 0 && i < 7) c[i]++;
    }
    return c;
  }

  /// Highest-frequency trigger category from mood logs; empty if none.
  String? get topTriggerCategoryFromLogs {
    final c = triggerCategoryCounts;
    var bestK = '';
    var bestV = -1;
    for (final e in c.entries) {
      if (e.value > bestV) {
        bestV = e.value;
        bestK = e.key;
      }
    }
    if (bestV <= 0) return null;
    return bestK;
  }

  int modeAttempts(String mode) => _craveSessions.where((e) => e.mode == mode).length;

  double modeHelpRate(String mode) {
    final attempts = modeAttempts(mode);
    if (attempts == 0) return 0;
    final helped = _craveSessions.where((e) => e.mode == mode && e.helped).length;
    return helped / attempts;
  }

  ({String mode, double rate, int attempts})? bestCraveModeSuggestion() {
    const modes = [
      'breath_60s',
      'urge_surf_5m',
      'distraction_task',
      'call_buddy',
    ];
    ({String mode, double rate, int attempts})? best;
    for (final mode in modes) {
      final attempts = modeAttempts(mode);
      if (attempts <= 0) continue;
      final rate = modeHelpRate(mode);
      if (best == null ||
          rate > best.rate ||
          (rate == best.rate && attempts > best.attempts)) {
        best = (mode: mode, rate: rate, attempts: attempts);
      }
    }
    return best;
  }

  void recordCraveOutcome({required String mode, required bool helped}) {
    _craveSessions.add(
      CraveSessionEntry(
        mode: mode.trim().isEmpty ? 'unknown' : mode.trim(),
        helped: helped,
        at: DateTime.now().toUtc(),
      ),
    );
    notifyListeners();
  }

  void recordResist() {
    resistCount += 1;
    lastResistAt = DateTime.now().toUtc();
    final i = DateTime.now().weekday % 7;
    if (i < _heatmapWeek.length) {
      _heatmapWeek[i] = (_heatmapWeek[i] + 1).clamp(0, 4);
    }
    notifyListeners();
  }

  void logTrigger(String emotion) {
    _triggerLog.add(emotion);
    lastMoodLoggedAt = DateTime.now().toUtc();
    notifyListeners();
  }

  void setLastRelapse(DateTime when) {
    lastRelapseDate = when;
    notifyListeners();
  }

  void setPersonalPlan({
    required String goalType,
    required String quitReason,
    required List<String> triggerProfile,
    required int milestoneDays,
  }) {
    this.goalType = goalType.trim().isEmpty ? 'quit' : goalType.trim();
    this.quitReason = quitReason.trim();
    this.triggerProfile = List<String>.from(
      triggerProfile.map((e) => e.trim()).where((e) => e.isNotEmpty),
    );
    this.milestoneDays = _sanitizeMilestoneDays(milestoneDays);
    onboardingCompleted = true;
    notifyListeners();
  }

  static int _sanitizeMilestoneDays(int value) {
    if (milestoneOptions.contains(value)) return value;
    return 30;
  }

  static String _sanitizeCurrencyPreference(String value) {
    const options = {'auto', 'INR', 'USD'};
    final v = value.trim().toUpperCase();
    if (v == 'AUTO') return 'auto';
    if (options.contains(v)) return v;
    return 'auto';
  }

  void replaceFromJson(Map<String, dynamic> json) {
    final did = json['device_id'];
    if (did is String && did.isNotEmpty) deviceId = did;
    final dn = json['display_name'];
    if (dn is String && dn.isNotEmpty) displayName = dn;
    final oc = json['onboarding_completed'];
    if (oc is bool) onboardingCompleted = oc;
    final gt = json['goal_type'];
    if (gt is String && gt.trim().isNotEmpty) goalType = gt.trim();
    final qr = json['quit_reason'];
    if (qr is String) quitReason = qr;
    final tp = json['trigger_profile'];
    if (tp is List) {
      triggerProfile = tp.map((e) => e.toString()).toList();
    }
    final md = json['milestone_days'];
    if (md is num) milestoneDays = _sanitizeMilestoneDays(md.toInt());
    final pc = json['preferred_currency'];
    if (pc is String) preferredCurrency = _sanitizeCurrencyPreference(pc);
    final lr = json['last_relapse_date'];
    if (lr is String) {
      lastRelapseDate = DateTime.tryParse(lr) ?? lastRelapseDate;
    }
    final v = json['version'];
    if (v is int) version = v;
    final rc = json['resist_count'];
    if (rc is int) resistCount = rc;
    final ds = json['daily_spend'];
    if (ds is num) dailySpend = ds.toDouble().clamp(0.0, 1000000.0);
    final dh = json['daily_hours'];
    if (dh is num) dailyHours = dh.toDouble().clamp(0.0, 24.0);
    final tl = json['trigger_log'];
    if (tl is List) {
      _triggerLog
        ..clear()
        ..addAll(tl.map((e) => e.toString()));
    }
    final cs = json['crave_sessions'];
    if (cs is List) {
      _craveSessions
        ..clear()
        ..addAll(
          cs.whereType<Map>().map((e) => CraveSessionEntry.fromJson(Map<String, dynamic>.from(e))),
        );
    }
    final hm = json['heatmap_week'];
    if (hm is List && hm.length == 7) {
      _heatmapWeek
        ..clear()
        ..addAll(hm.map((e) => (e as num).toInt().clamp(0, 4)));
    }
    if (json.containsKey('last_mood_logged_at')) {
      final lm = json['last_mood_logged_at'];
      lastMoodLoggedAt = lm is String ? DateTime.tryParse(lm) : null;
    }
    if (json.containsKey('last_resist_at')) {
      final lrs = json['last_resist_at'];
      lastResistAt = lrs is String ? DateTime.tryParse(lrs) : null;
    }
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'display_name': displayName,
        'onboarding_completed': onboardingCompleted,
        'goal_type': goalType,
        'quit_reason': quitReason,
        'trigger_profile': List<String>.from(triggerProfile),
        'milestone_days': milestoneDays,
        'preferred_currency': preferredCurrency,
        'daily_spend': dailySpend,
        'daily_hours': dailyHours,
        'version': version,
        'last_relapse_date': lastRelapseDate.toUtc().toIso8601String(),
        'resist_count': resistCount,
        'trigger_log': List<String>.from(_triggerLog),
        'crave_sessions': _craveSessions.map((e) => e.toJson()).toList(),
        'heatmap_week': List<int>.from(_heatmapWeek),
        'last_mood_logged_at': lastMoodLoggedAt?.toUtc().toIso8601String(),
        'last_resist_at': lastResistAt?.toUtc().toIso8601String(),
      };
}
