import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/fcm_service.dart';

/// يدير حالة تسجيل الدخول ويُشغّل المزامنة الأولية بعد الدخول مباشرةً
class AuthProvider extends ChangeNotifier {
  final AuthService  _authService;
  final SyncService  _syncService;

  AppUser? _currentUser;
  bool     _isLoading       = false;
  bool     _isSyncing       = false; // ← شاشة التحميل
  String?  _errorMessage;

  AuthProvider(this._authService, this._syncService) {
    // استعادة الجلسة تلقائيًا عند إعادة فتح التطبيق
    _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  AppUser? get currentUser   => _currentUser;
  bool     get isLoading     => _isLoading;
  bool     get isSyncing     => _isSyncing;   // ← يُستخدم في AuthWrapper
  String?  get errorMessage  => _errorMessage;
  bool     get isLoggedIn    => _currentUser != null;
  bool     get isAdmin       => _currentUser?.isAdmin ?? false;

  // ─── استعادة الجلسة التلقائية ─────────────────────────────────────────────

  Future<void> _onAuthStateChanged(User? user) async {
    if (user == null) {
      _currentUser = null;
      _isSyncing   = false;
      _syncService.stopListeners();
      notifyListeners();
      return;
    }

    // المستخدم موجود (استعادة جلسة) → مزامنة أولية
    try {
      _currentUser = await _authService.fetchAppUser(user.uid);
    } catch (_) {
      _currentUser = null;
      notifyListeners();
      return;
    }

    // بدء المزامنة مع شاشة التحميل
    _isSyncing = true;
    notifyListeners();

    await _syncService.performInitialSync();

    _isSyncing = false;
    notifyListeners();

    // حفظ FCM token واستقبال الإشعارات
    if (_currentUser != null) {
      try {
        await FcmService().saveToken(_currentUser!.uid);
        FcmService().startListeningForNotifications(_currentUser!.uid);
      } catch (_) {}
    }
  }

  // ─── تسجيل الدخول ────────────────────────────────────────────────────────

  Future<bool> login(String email, String password) async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authService.signIn(email, password);
      _isLoading   = false;
      notifyListeners(); // ← AuthWrapper سيرى isLoggedIn=true

      // بدء المزامنة الأولية مع شاشة التحميل
      _isSyncing = true;
      notifyListeners();

      await _syncService.performInitialSync();

      _isSyncing = false;
      notifyListeners();

      // حفظ FCM token بعد تسجيل الدخول لإرسال الإشعارات الحقيقية
      if (_currentUser != null) {
        try {
          await FcmService().saveToken(_currentUser!.uid);
          FcmService().startListeningForNotifications(_currentUser!.uid);
        } catch (_) {}
      }
      return true;

    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _isLoading    = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading    = false;
      notifyListeners();
      return false;
    }
  }

  // ─── تسجيل الخروج ────────────────────────────────────────────────────────

  Future<void> logout() async {
    _syncService.stopListeners();
    FcmService().stopListeningForNotifications();
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }

  // ─── ترجمة أخطاء Firebase ─────────────────────────────────────────────────

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'لا يوجد حساب بهذا البريد الإلكتروني';
      case 'wrong-password':
      case 'invalid-credential':
        return 'كلمة المرور غير صحيحة';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة';
      case 'too-many-requests':
        return 'محاولات كثيرة جدًا، حاول لاحقًا';
      default:
        return 'حدث خطأ أثناء تسجيل الدخول';
    }
  }
}
