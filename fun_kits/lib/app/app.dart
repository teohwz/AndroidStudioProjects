import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/services/auth_service.dart';
import '../features/auth/login_screen.dart';
import '../features/home/home_screen.dart';
import '../features/admin/admin_dashboard_screen.dart';
import 'routes.dart';

class FunKitsApp extends StatelessWidget {
  const FunKitsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fun Kits',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        fontFamily: 'Nunito',
        useMaterial3: true,
      ),
      routes: AppRoutes.routes,
      home: Consumer<AuthService>(
        builder: (context, auth, _) {
          if (auth.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (auth.currentUser == null) return const LoginScreen();
          // Route based on role
          return auth.isAdmin
              ? const AdminDashboardScreen()
              : const HomeScreen();
        },
      ),
    );
  }
}
