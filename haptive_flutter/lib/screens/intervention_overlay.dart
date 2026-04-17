import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../services/habit_api.dart';
import '../state/habit_store.dart';
import '../theme/haptive_theme.dart';

/// Full-screen overlay — breathe pacer + grounding actions (Crave control).
class InterventionOverlay extends StatefulWidget {
  const InterventionOverlay({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<InterventionOverlay> createState() => _InterventionOverlayState();
}

class _InterventionOverlayState extends State<InterventionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;
  String _selectedMode = 'breath_60s';

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _breath.addStatusListener((status) {
      if (!mounted) return;
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        HapticFeedback.lightImpact();
      }
    });
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  void _haptic() => HapticFeedback.mediumImpact();

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: HaptiveColors.border),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _askOutcomeAndTrack({
    required String mode,
    String? tagTrigger,
  }) async {
    final helped = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: HaptiveColors.surface,
          surfaceTintColor: Colors.transparent,
          title: const Text('Did this help?'),
          content: const Text('Your answer improves which tools we suggest next.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not really'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, helped'),
            ),
          ],
        );
      },
    );
    if (helped == null || !mounted) return;
    final store = context.read<HabitStore>();
    if (tagTrigger != null && tagTrigger.isNotEmpty) {
      store.logTrigger(tagTrigger);
      try {
        await HabitApi().postTrigger(store, tagTrigger);
      } catch (_) {}
    }
    store.recordCraveOutcome(mode: mode, helped: helped);
    try {
      await HabitApi().postCraveSession(
        store,
        mode: mode,
        helped: helped,
      );
    } catch (_) {}
    if (!mounted) return;
    _snack(
      context,
      helped
          ? 'Nice. Logged as helpful for ${_modeUi(mode)}.'
          : 'Logged. We will keep tuning what works for you.',
    );
  }

  String _modeUi(String mode) {
    switch (mode) {
      case 'urge_surf_5m':
        return 'urge surf';
      case 'distraction_task':
        return 'distraction';
      case 'call_buddy':
        return 'call buddy';
      default:
        return 'breathing';
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
            child: Container(color: Colors.black.withValues(alpha: 0.58)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          _haptic();
                          widget.onClose();
                        },
                        icon:
                            const Icon(Icons.close_rounded, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Crave control',
                            style: text.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            'Urge riding',
                            style: text.labelSmall?.copyWith(
                              color: HaptiveColors.label,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Ride this urge',
                    textAlign: TextAlign.center,
                    style: text.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use a steady pace: 4 seconds in, 4 seconds out. '
                    'Follow the ring as it expands and contracts.',
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(
                      color: HaptiveColors.label,
                      height: 1.45,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _ModeChip(
                        label: '60s breath',
                        selected: _selectedMode == 'breath_60s',
                        onTap: () => setState(() => _selectedMode = 'breath_60s'),
                      ),
                      _ModeChip(
                        label: '5m urge surf',
                        selected: _selectedMode == 'urge_surf_5m',
                        onTap: () => setState(() => _selectedMode = 'urge_surf_5m'),
                      ),
                      _ModeChip(
                        label: 'Distraction',
                        selected: _selectedMode == 'distraction_task',
                        onTap: () => setState(() => _selectedMode = 'distraction_task'),
                      ),
                      _ModeChip(
                        label: 'Call buddy',
                        selected: _selectedMode == 'call_buddy',
                        onTap: () => setState(() => _selectedMode = 'call_buddy'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final maxRingSize = math.min(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        final ringSize = maxRingSize.clamp(180.0, 280.0);
                        final scaleFactor = ringSize / 280.0;

                        return Center(
                          child: AnimatedBuilder(
                            animation: _breath,
                            builder: (context, _) {
                              final v = _breath.value;
                              final inhaling =
                                  _breath.status == AnimationStatus.forward;
                              final scale = 0.82 + 0.24 * v;
                              var countdown = inhaling
                                  ? ((1.0 - v) * 4).ceil()
                                  : (v * 4).ceil();
                              if (countdown < 1) countdown = 1;
                              if (countdown > 4) countdown = 4;

                              return SizedBox(
                                width: ringSize,
                                height: ringSize,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Transform.rotate(
                                      angle: -math.pi / 2,
                                      child: SizedBox(
                                        width: ringSize * 0.985,
                                        height: ringSize * 0.985,
                                        child: CircularProgressIndicator(
                                          value: v,
                                          strokeWidth: 5 * scaleFactor,
                                          strokeCap: StrokeCap.round,
                                          backgroundColor: Colors.white
                                              .withValues(alpha: 0.08),
                                          color: HaptiveColors.progress,
                                        ),
                                      ),
                                    ),
                                    Transform.scale(
                                      scale: scale,
                                      child: Container(
                                        width: ringSize * 0.79,
                                        height: ringSize * 0.79,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: HaptiveColors.progress
                                                  .withValues(
                                                alpha: 0.18 + v * 0.18,
                                              ),
                                              blurRadius: 40 * scaleFactor,
                                              spreadRadius: 2 * scaleFactor,
                                            ),
                                            BoxShadow(
                                              color: HaptiveColors.clean
                                                  .withValues(alpha: 0.07),
                                              blurRadius: 28 * scaleFactor,
                                            ),
                                          ],
                                        ),
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: HaptiveColors.progress
                                                  .withValues(
                                                alpha: 0.72 + v * 0.2,
                                              ),
                                              width: 3 * scaleFactor,
                                            ),
                                            gradient: RadialGradient(
                                              colors: [
                                                Colors.white
                                                    .withValues(alpha: 0.07),
                                                Colors.transparent,
                                              ],
                                              stops: const [0.35, 1],
                                            ),
                                          ),
                                          child: Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  '$countdown',
                                                  style: text.displayLarge
                                                      ?.copyWith(
                                                    fontSize: 44 * scaleFactor,
                                                    fontWeight: FontWeight.w800,
                                                    color: HaptiveColors.clean,
                                                    letterSpacing:
                                                        -1.5 * scaleFactor,
                                                    height: 1,
                                                    fontFeatures: const [
                                                      FontFeature
                                                          .tabularFigures(),
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(
                                                  height: 2 * scaleFactor,
                                                ),
                                                Text(
                                                  inhaling ? 'Inhale' : 'Exhale',
                                                  style: text.titleSmall
                                                      ?.copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 20 * scaleFactor,
                                                    letterSpacing:
                                                        -0.3 * scaleFactor,
                                                  ),
                                                ),
                                                SizedBox(
                                                  height: 4 * scaleFactor,
                                                ),
                                                Text(
                                                  inhaling
                                                      ? 'Nose · belly expands'
                                                      : 'Mouth · let it go',
                                                  style: text.labelSmall
                                                      ?.copyWith(
                                                    color: HaptiveColors.label,
                                                    fontSize: 12 * scaleFactor,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reset your focus',
                    style: text.labelSmall?.copyWith(
                      color: HaptiveColors.label,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 360;
                      final children = [
                        _CraveActionTile(
                          icon: LucideIcons.activity,
                          label: 'Urge surf',
                          hint: 'Ride 10 minutes',
                          accent: HaptiveColors.clean,
                          onTap: () async {
                            _haptic();
                            await _askOutcomeAndTrack(
                              mode: _selectedMode,
                              tagTrigger: 'Stress',
                            );
                          },
                        ),
                        _CraveActionTile(
                          icon: LucideIcons.sparkles,
                          label: '5-4-3-2-1',
                          hint: 'Use your senses',
                          accent: HaptiveColors.progress,
                          onTap: () async {
                            _haptic();
                            _snack(
                              context,
                              'Try 5 things you see, 4 feel, 3 hear, 2 smell, 1 taste.',
                            );
                            await _askOutcomeAndTrack(
                              mode: _selectedMode,
                              tagTrigger: 'Social',
                            );
                          },
                        ),
                        _CraveActionTile(
                          icon: LucideIcons.target,
                          label: '10-min walk',
                          hint: 'Move your body',
                          accent: const Color(0xFFC084FC),
                          onTap: () async {
                            _haptic();
                            await _askOutcomeAndTrack(
                              mode: _selectedMode,
                              tagTrigger: 'Boredom',
                            );
                          },
                        ),
                      ];
                      if (narrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < children.length; i++) ...[
                              if (i > 0) const SizedBox(height: 10),
                              children[i],
                            ],
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: children[0]),
                          const SizedBox(width: 10),
                          Expanded(child: children[1]),
                          const SizedBox(width: 10),
                          Expanded(child: children[2]),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _askOutcomeAndTrack(mode: _selectedMode),
                    child: Text('Complete ${_modeUi(_selectedMode)}'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CraveActionTile extends StatelessWidget {
  const _CraveActionTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF151518),
                HaptiveColors.surface.withValues(alpha: 0.95),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.14),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: text.labelSmall?.copyWith(
                    color: HaptiveColors.label,
                    fontSize: 10,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected
                ? HaptiveColors.progress.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.03),
            border: Border.all(
              color: selected
                  ? HaptiveColors.progress.withValues(alpha: 0.6)
                  : HaptiveColors.border.withValues(alpha: 0.9),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 15,
                color: selected ? HaptiveColors.progress : HaptiveColors.label,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : HaptiveColors.label,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
