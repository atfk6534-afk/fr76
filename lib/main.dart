import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'auth_wrapper.dart';
import 'core/theme/app_theme.dart';

import 'services/local_db_service.dart';
import 'services/firestore_service.dart';
import 'services/connectivity_service.dart';
import 'services/sync_service.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart';

import 'providers/auth_provider.dart';
import 'providers/student_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/visit_provider.dart';
import 'providers/trip_provider.dart';
import 'providers/schedule_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── لازم يتسجل قبل Firebase.initializeApp ──────────────────────────────
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Local DB ─────────────────────────────────────────────────────────────
  final localDb = LocalDbService();
  await localDb.init();

  // ── FCM ──────────────────────────────────────────────────────────────────
  final fcm = FcmService();
  await fcm.init();

  // ── Services ─────────────────────────────────────────────────────────────
  final firestoreService    = FirestoreService();
  final authService         = AuthService();
  final connectivityService = ConnectivityService();
  final syncService = SyncService(localDb, firestoreService, connectivityService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(authService, syncService)),
        ChangeNotifierProvider(create: (_) => StudentProvider(localDb, syncService)),
        ChangeNotifierProvider(create: (_) => AttendanceProvider(localDb, syncService)),
        ChangeNotifierProvider(create: (_) => VisitProvider(localDb, syncService)),
        ChangeNotifierProvider(create: (_) => SettingsProvider(firestoreService, connectivityService)),
        ChangeNotifierProvider(create: (_) => TripProvider(localDb, firestoreService)),
        ChangeNotifierProvider(create: (_) => ScheduleProvider(localDb, firestoreService, fcm)),
      ],
      child: const LahanAttendanceApp(),
    ),
  );
}

class LahanAttendanceApp extends StatelessWidget {
  const LahanAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      title: 'متابعة حضور حصة ألحان',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme:     AppTheme.lightTheme(settings.fontScale),
      darkTheme: AppTheme.darkTheme(settings.fontScale),
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const AuthWrapper(),
    );
  }
}
