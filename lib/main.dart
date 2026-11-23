import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'shared/providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final configStore = AppConfigStore(prefs);

  runApp(
    ProviderScope(
      overrides: [
        appConfigStoreProvider.overrideWithValue(configStore),
      ],
      child: const TermFlowApp(),
    ),
  );
}
