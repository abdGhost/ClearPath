import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../services/habit_api.dart';
import '../state/habit_store.dart';
import '../theme/haptive_theme.dart';

/// Analytics — card-grouped layout, weekday bar chart, trigger mix (common in habit / health apps).
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _api = HabitApi();
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>>? _modes;
  List<int>? _weeklyActivity;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  /// [heatmapWeek] storage uses `weekday % 7` (Sun = 0 … Sat = 6). UI is Mon-first.
  static const _heatmapStorageMondayFirst = [1, 2, 3, 4, 5, 6, 0];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh(context));
  }

  Future<void> _refresh(BuildContext context) async {
    final store = context.read<HabitStore>();
    try {
      await _api.applyRemoteState(store);
      final summary = await _api.getSummary(store);
      final modes = await _api.getModes(store);
      final weekly = await _api.getWeeklyActivity(store);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _modes = modes;
        _weeklyActivity = weekly;
      });
    } catch (_) {
      /* offline */
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HabitStore>();
    final text = Theme.of(context).textTheme;
    final remoteTopTrigger = _summary?['top_trigger'];
    final remoteModeStats = _modes ?? const <Map<String, dynamic>>[];
    final modeStatsByMode = {
      for (final row in remoteModeStats)
        (row['mode']?.toString() ?? ''): row,
    };
    final counts = store.triggerCategoryCounts;
    final triggerTotal = store.triggerLog.length;
    final unmatched = store.triggerUnmatchedCount;
    final topTriggerLabel = (remoteTopTrigger is String && remoteTopTrigger.trim().isNotEmpty)
        ? remoteTopTrigger
        : store.topTriggerCategoryFromLogs ??
        (store.triggerProfile.isNotEmpty ? store.triggerProfile.first : '—');
    final weekdayActivity = (_weeklyActivity != null && _weeklyActivity!.length == 7)
        ? _weeklyActivity!
        : List<int>.generate(7, (col) {
            final storageI = _heatmapStorageMondayFirst[col];
            return store.weekdayCraveSessionCounts[col] + store.heatmapWeek[storageI];
          });
    final maxWeekdayActivity =
        weekdayActivity.fold<int>(0, (a, b) => a > b ? a : b);
    final totalCraveSessions = store.craveSessions.length;
    final recentTags = store.triggerLog.isEmpty
        ? const <String>[]
        : store.triggerLog.reversed.take(8).toList();
    final modes = const [
      ('breath_60s', '60s breath'),
      ('urge_surf_5m', '5m urge surf'),
      ('distraction_task', 'Distraction'),
      ('call_buddy', 'Call buddy'),
    ];

    return Scaffold(
      backgroundColor: HaptiveColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: widget.embedded ? 52 : 56,
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: Colors.white,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).maybePop();
                },
              ),
        title: Column(
          crossAxisAlignment:
              widget.embedded ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Analytics',
              style: text.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.6,
                height: 1.1,
              ),
            ),
            Text(
              'Weekly rhythm · trigger mix',
              style: text.labelSmall?.copyWith(
                color: HaptiveColors.label.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
        centerTitle: widget.embedded,
      ),
      body: RefreshIndicator(
        color: HaptiveColors.clean,
        backgroundColor: HaptiveColors.surface,
        displacement: 48,
        onRefresh: () => _refresh(context),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 40),
          children: [
            _AnalyticsSurface(
              child: Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: 'Goal',
                      value: store.goalType == 'reduce' ? 'Reduce' : 'Quit',
                      icon: LucideIcons.flag,
                      accent: HaptiveColors.clean,
                    ),
                  ),
                  _statGutter(),
                  Expanded(
                    child: _StatTile(
                      label: 'Milestone',
                      value: '${store.milestoneDays}d',
                      icon: LucideIcons.calendarDays,
                      accent: HaptiveColors.progress,
                    ),
                  ),
                  _statGutter(),
                  Expanded(
                    child: _StatTile(
                      label: 'Top trigger',
                      value: topTriggerLabel,
                      icon: LucideIcons.sparkles,
                      accent: const Color(0xFFC084FC),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _AnalyticsSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHead(
                    text,
                    LucideIcons.heart,
                    HaptiveColors.clean,
                    'What helps most',
                    'Effectiveness from your “Did this help?” answers.',
                  ),
                  if (totalCraveSessions == 0) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Use Crave control on Pulse and tap how each tactic felt — stats appear here.',
                      style: text.bodySmall?.copyWith(
                        color: HaptiveColors.label,
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  for (final m in modes) ...[
                    _ModeEffectRow(
                      label: m.$2,
                      attempts: (modeStatsByMode[m.$1]?['attempts'] as num?)?.toInt() ??
                          store.modeAttempts(m.$1),
                      helpRate: (modeStatsByMode[m.$1]?['help_rate'] as num?)?.toDouble() ??
                          store.modeHelpRate(m.$1),
                    ),
                    if (m != modes.last) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            _AnalyticsSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHead(
                    text,
                    LucideIcons.flame,
                    HaptiveColors.clean,
                    'When you show up',
                    'Per weekday: Crave sessions logged + Resist taps (Pulse).',
                  ),
                  const SizedBox(height: 20),
                  if (maxWeekdayActivity == 0)
                    Text(
                      'No weekday activity yet — resist a craving or finish a Crave control session.',
                      style: text.bodySmall?.copyWith(
                        color: HaptiveColors.label,
                        height: 1.45,
                      ),
                    )
                  else
                  SizedBox(
                    height: 120,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(7, (col) {
                        final v = weekdayActivity[col];
                        final t = maxWeekdayActivity > 0
                            ? (v / maxWeekdayActivity).clamp(0.0, 1.0)
                            : 0.0;
                        // Keep bar + label + gaps within fixed chart height (avoids overflow on web).
                        final barH =
                            12.0 + t * 72.0; // 12–84
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  height: barH,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(8),
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        HaptiveColors.progress.withValues(
                                          alpha: 0.25 + t * 0.45,
                                        ),
                                        _HeatmapAccent.highlight
                                            .withValues(alpha: 0.5 + t * 0.4),
                                      ],
                                    ),
                                    boxShadow: t > 0
                                        ? [
                                            BoxShadow(
                                              color: HaptiveColors.progress
                                                  .withValues(alpha: 0.22),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _dayLabels[col],
                                  style: text.labelSmall?.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withValues(
                                      alpha: 0.82,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _AnalyticsSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHead(
                    text,
                    LucideIcons.activity,
                    HaptiveColors.progress,
                    'What showed up',
                    'From Crave control — share of all tag logs.',
                  ),
                  const SizedBox(height: 18),
                  if (triggerTotal == 0)
                    Text(
                      'No tags yet. Open Crave control on Pulse and tap a quick action once.',
                      style: text.bodySmall?.copyWith(
                        color: HaptiveColors.label,
                        height: 1.45,
                      ),
                    )
                  else ...[
                    _TriggerMixRow(
                      label: 'Stress',
                      hint: 'Brain Game',
                      count: counts['Stress'] ?? 0,
                      total: triggerTotal,
                      color: HaptiveColors.progress,
                    ),
                    const SizedBox(height: 18),
                    _TriggerMixRow(
                      label: 'Boredom',
                      hint: 'Quick Journal',
                      count: counts['Boredom'] ?? 0,
                      total: triggerTotal,
                      color: HaptiveColors.clean,
                    ),
                    const SizedBox(height: 18),
                    _TriggerMixRow(
                      label: 'Social',
                      hint: 'Emergency call',
                      count: counts['Social'] ?? 0,
                      total: triggerTotal,
                      color: const Color(0xFFC084FC),
                    ),
                    if (unmatched > 0) ...[
                      const SizedBox(height: 14),
                      Text(
                        '$unmatched ${_plural(unmatched, 'log', 'logs')} weren’t one of these three tags.',
                        style: text.labelSmall?.copyWith(
                          color: HaptiveColors.label.withValues(alpha: 0.72),
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            if (recentTags.isNotEmpty) ...[
              const SizedBox(height: 14),
              _AnalyticsSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHead(
                      text,
                      LucideIcons.history,
                      HaptiveColors.label,
                      'Latest tags',
                      'Most recent check-ins.',
                    ),
                    const SizedBox(height: 14),
                    for (var i = 0; i < recentTags.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      _RecentTagPill(label: recentTags[i]),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _plural(int n, String one, String many) => n == 1 ? one : many;

  static Widget _sectionHead(
    TextTheme text,
    IconData icon,
    Color iconColor,
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: iconColor.withValues(alpha: 0.12),
                border: Border.all(color: iconColor.withValues(alpha: 0.22)),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: text.labelSmall?.copyWith(
                      color: HaptiveColors.label.withValues(alpha: 0.92),
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static Widget _statGutter() {
    return Container(
      width: 1,
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            HaptiveColors.border.withValues(alpha: 0.65),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _ModeEffectRow extends StatelessWidget {
  const _ModeEffectRow({
    required this.label,
    required this.attempts,
    required this.helpRate,
  });

  final String label;
  final int attempts;
  final double helpRate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pct = (helpRate * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: text.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              attempts == 0 ? 'No data' : '$pct% (${attempts}x)',
              style: text.labelSmall?.copyWith(
                color: HaptiveColors.label,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: helpRate.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.06),
            valueColor: const AlwaysStoppedAnimation<Color>(HaptiveColors.clean),
          ),
        ),
      ],
    );
  }
}

/// Rounded elevated block — typical of health / streak dashboards (grouped content, clear edges).
class _AnalyticsSurface extends StatelessWidget {
  const _AnalyticsSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.09),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF141418),
            HaptiveColors.surface.withValues(alpha: 0.92),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Icon(icon, size: 22, color: accent),
        const SizedBox(height: 8),
        Text(
          value,
          style: text.titleMedium?.copyWith(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: text.labelSmall?.copyWith(
            fontSize: 11,
            color: HaptiveColors.label,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _HeatmapAccent {
  static Color get highlight => const Color(0xFF00B2FF);
}

class _TriggerMixRow extends StatelessWidget {
  const _TriggerMixRow({
    required this.label,
    required this.hint,
    required this.count,
    required this.total,
    required this.color,
  });

  final String label;
  final String hint;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final frac = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;
    final pct = total > 0 ? (frac * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: text.titleMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    hint,
                    style: text.labelSmall?.copyWith(
                      fontSize: 11,
                      color: HaptiveColors.label.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$pct%',
              style: text.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w800,
                fontSize: 13,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '($count)',
              style: text.labelSmall?.copyWith(
                color: HaptiveColors.label.withValues(alpha: 0.75),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.06),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _RecentTagPill extends StatelessWidget {
  const _RecentTagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: HaptiveColors.border.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: text.bodySmall?.copyWith(
          color: Colors.white.withValues(alpha: 0.94),
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
    );
  }
}
