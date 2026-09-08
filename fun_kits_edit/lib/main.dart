import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'app/app.dart';
import 'core/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // The Role Choice screen (Exhibitor / Visitor) now decides when an
  // anonymous session gets created — see RoleChoiceScreen and app.dart's
  // bootstrap logic. All that's needed up front is the persisted "last
  // login mode" flag (SharedPreferences only, no network) so app.dart
  // knows immediately whether to show that choice screen, the Exhibitor
  // Login page, or the Visitor Login page, for a device with no current
  // Firebase session.
  final authService = AuthService();
  await authService.loadLastMode();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
      ],
      child: const FunKitsApp(),
    ),
  );
}
