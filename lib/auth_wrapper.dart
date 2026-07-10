import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'core/constants/app_colors.dart';

/// يقرر هذا الويدجت أي شاشة تُعرض:
///   • لم يدخل بعد → LoginScreen
///   • دخل ويجري المزامنة → شاشة التحميل
///   • دخل والمزامنة اكتملت → HomeScreen
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // لم يسجّل دخول
    if (!auth.isLoggedIn) return const LoginScreen();

    // سجّل دخول والمزامنة الأولية جارية
    if (auth.isSyncing) return const _SyncLoadingScreen();

    // جاهز
    return const HomeScreen();
  }
}

/// شاشة التحميل أثناء المزامنة الأولية
class _SyncLoadingScreen extends StatelessWidget {
  const _SyncLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // شعار التطبيق
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.cloud_sync_rounded,
                size: 56,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'جاري تحميل البيانات...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'يُرجى الانتظار حتى اكتمال المزامنة',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
