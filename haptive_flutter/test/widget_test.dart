import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haptive_flutter/main.dart';
import 'package:provider/provider.dart';

import 'package:haptive_flutter/state/habit_store.dart';

void main() {
  testWidgets('shows onboarding for first run', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => HabitStore(),
        child: const HaptiveApp(),
      ),
    );

    expect(find.byKey(const ValueKey('onboarding-screen')), findsOneWidget);
  });

  testWidgets('home tab shows streak after onboarding complete', (WidgetTester tester) async {
    final store = HabitStore();
    store.setPersonalPlan(
      goalType: 'quit',
      quitReason: 'Health',
      triggerProfile: const ['Stress'],
      milestoneDays: 60,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => store,
        child: const HaptiveApp(),
      ),
    );

    expect(find.byKey(const ValueKey('pulse-typography-home')), findsOneWidget);
    expect(find.text('Path to 60 days'), findsOneWidget);
  });
}
