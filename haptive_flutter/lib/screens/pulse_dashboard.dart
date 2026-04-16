import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../services/habit_api.dart';
import '../state/habit_store.dart';
import '../theme/haptive_theme.dart';
import '../widgets/pulse_typography_home.dart';
import '../widgets/sync_status_badge.dart';
import 'intervention_overlay.dart';

/// Pulse home — minimal typography + ring hero (trend in dark habit apps).
class PulseDashboard extends StatefulWidget {
  const PulseDashboard({super.key});

  @override
  State<PulseDashboard> createState() => _PulseDashboardState();
}

class _PulseDashboardState extends State<PulseDashboard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  static const _mantras = [
    'One breath at a time.',
    'Urges pass. You stay.',
    'Small steps add up.',
  ];

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    try {
      await HabitApi().applyRemoteState(context.read<HabitStore>());
    } catch (_) {
      /* offline */
    }
  }

  Future<void> _openIntervention() async {
    final store = context.read<HabitStore>();
    HapticFeedback.heavyImpact();
    store.recordResist();
    try {
      await HabitApi().postResist(store);
    } catch (_) {
      /* offline */
    }
    await _pulse.forward(from: 0);
    _pulse.reset();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (context, animation, secondary) {
          return FadeTransition(
            opacity: animation,
            child: InterventionOverlay(
              onClose: () => Navigator.of(context).pop(),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondary, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          );
        },
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatDate(DateTime d) {
    return '${_weekday(d)}, ${_months[d.month - 1]} ${d.day}';
  }

  String _weekday(DateTime d) {
    const names = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[d.weekday - 1];
  }

  String _displayNameForUi(String raw) {
    final i = raw.indexOf(' #');
    if (i <= 0) return raw;
    return raw.substring(0, i);
  }

  static String _modeUi(String mode) {
    switch (mode) {
      case 'urge_surf_5m':
        return '5m urge surf';
      case 'distraction_task':
        return 'distraction';
      case 'call_buddy':
        return 'call buddy';
      default:
        return '60s breath';
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HabitStore>();
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: HaptiveColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              color: HaptiveColors.clean,
              backgroundColor: HaptiveColors.surface,
              displacement: 40,
              onRefresh: _onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 132),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatDate(now).toUpperCase(),
                          style: text.labelSmall?.copyWith(
                            color: HaptiveColors.label.withValues(alpha: 0.9),
                            fontSize: 11,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SyncStatusBadge(
                        syncing: store.isSyncing,
                        label: store.syncStatusMessage,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _greeting(),
                    style: text.displayLarge?.copyWith(
                      fontSize: 32,
                      color: Colors.white,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  if (store.displayName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _displayNameForUi(store.displayName),
                      style: text.labelMedium?.copyWith(
                        color: HaptiveColors.label.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    _mantras[now.day % _mantras.length],
                    style: text.bodyMedium?.copyWith(
                      color: HaptiveColors.label,
                      fontSize: 15,
                      height: 1.45,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (store.bestCraveModeSuggestion() case final best?) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Start with ${_modeUi(best.mode)} — ${(best.rate * 100).round()}% helpful for you.',
                      style: text.labelSmall?.copyWith(
                        color: HaptiveColors.progress.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  PulseTypographyHome(store: store),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      HaptiveColors.background.withValues(alpha: 0.0),
                      HaptiveColors.background.withValues(alpha: 0.88),
                      HaptiveColors.background,
                    ],
                  ),
                ),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 1, end: 1.02).animate(
                    CurvedAnimation(parent: _pulse, curve: Curves.easeOutBack),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: _PrimaryCta(onPressed: _openIntervention),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Solid primary — single confident action (minimal trackers use one clear CTA).
class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () {
        HapticFeedback.mediumImpact();
        onPressed();
      },
      style: FilledButton.styleFrom(
        backgroundColor: HaptiveColors.clean,
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.zap, size: 20, color: Colors.black.withValues(alpha: 0.85)),
          const SizedBox(width: 10),
          Text(
            'Control',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
          ),
        ],
      ),
    );
  }
}
