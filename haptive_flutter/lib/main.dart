import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/device_identity.dart';
import 'screens/onboarding_screen.dart';
import 'screens/app_shell.dart';
import 'state/habit_persistence.dart';
import 'state/habit_store.dart';
import 'theme/haptive_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final identity = await DeviceIdentityService.loadOrCreate();
  final store = await HabitPersistence.load();
  store.deviceId = identity.deviceId;
  store.displayName = identity.displayName;
  store.addListener(() {
    unawaited(HabitPersistence.save(store));
  });
  runApp(
    ChangeNotifierProvider(
      create: (_) => store,
      child: const HaptiveApp(),
    ),
  );
}

class HaptiveApp extends StatelessWidget {
  const HaptiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HabitStore>();
    return MaterialApp(
      title: 'ClearPath',
      debugShowCheckedModeBanner: false,
      theme: buildHaptiveTheme(),
      home: store.onboardingCompleted
          ? const HaptiveAppShell()
          : const OnboardingScreen(),
    );
  }
}

