import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// ─── Background handler — لازم يكون top-level function (مش داخل class) ───────
/// يُستدعى لما التطبيق في الخلفية أو مغلق ويوصله FCM message
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // لا تحتاج تهيئة Firebase هنا — Flutter يعملها تلقائياً قبل استدعاء الـ handler
  await FcmService._showBackgroundNotification(message);
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db  = FirebaseFirestore.instance;

  static final FlutterLocalNotificationsPlugin _notifPlugin =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notificationsSubscription;

  static bool _initialized = false;

  // ── channel ثابت لكل الإشعارات ───────────────────────────────────────────
  static const _channel = AndroidNotificationChannel(
    'schedule_channel',
    'تذكير التوزيع',
    description: 'إشعارات تذكير الكلمة واللحن',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  // ─── تهيئة أولية (تُستدعى من main() قبل runApp) ────────────────────────────
  Future<void> init() async {
    if (_initialized) return;

    // 1. أنشئ الـ Android notification channel
    await _notifPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 2. تهيئة flutter_local_notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit     = DarwinInitializationSettings(
      requestAlertPermission: false, // بنطلبها يدوياً بعدين
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _notifPlugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // 3. استقبال الرسائل وهو في الـ foreground
    FirebaseMessaging.onMessage.listen(_handleForeground);

    // 4. لما يضغط المستخدم على الإشعار وهو في الخلفية
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);

    // 5. اضبط FCM ليستقبل الإشعارات حتى في الخلفية على iOS
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _initialized = true;
  }

  // ─── طلب صلاحية الإشعارات ────────────────────────────────────────────────
  Future<bool> requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    return granted;
  }

  // ─── حفظ FCM token في Firestore ──────────────────────────────────────────
  Future<void> saveToken(String uid) async {
    try {
      final token = await _fcm.getToken();
      if (token == null || token.isEmpty) return;
      await _db.collection('users').doc(uid).update({'fcmToken': token});
      // تجديد الـ token تلقائياً لو اتغيّر
      _tokenSubscription?.cancel();
      _tokenSubscription = _fcm.onTokenRefresh.listen((newToken) async {
        await _db.collection('users').doc(uid).update({'fcmToken': newToken});
      });
    } catch (_) {}
  }

  // ─── استماع لإشعارات المستخدم من Firestore ──────────────────────────────────
  void startListeningForNotifications(String uid) {
    _notificationsSubscription?.cancel();
    _notificationsSubscription = _db
        .collection('pending_notifications')
        .where('toUid', isEqualTo: uid)
        .where('sent', isEqualTo: false)
        .snapshots()
        .listen((snap) async {
      for (final doc in snap.docs) {
        final data = doc.data();
        final scheduledFor = (data['scheduledFor'] as Timestamp?)?.toDate();
        if (scheduledFor != null && scheduledFor.isBefore(DateTime.now())) {
          await _showNotification(
            id: doc.id.hashCode.abs(),
            title: data['title'] ?? '',
            body: data['body'] ?? '',
          );
          await doc.reference.update({'sent': true});
        }
      }
    });
  }

  void stopListeningForNotifications() {
    _notificationsSubscription?.cancel();
    _notificationsSubscription = null;
  }

  // ─── إرسال إشعار جدولة مؤجّل عبر Firestore ──────────────────────────────
  /// الطريقة: يتحفظ الإشعار في Firestore مع scheduledFor
  /// Cloud Function بتراقب الـ collection وتبعت FCM push في الوقت الصح
  Future<void> sendScheduleNotification({
    required String   toUid,
    required String   assigneeName,
    required String   typeLabel,
    required String   activityName,
    required String   dateKey,
    required DateTime reminderTime,
    required String   assignmentId,
  }) async {
    // لا ترسل لو الوقت فات
    if (reminderTime.isBefore(DateTime.now())) return;

    await _db.collection('pending_notifications').add({
      'toUid':        toUid,
      'assignmentId': assignmentId,
      'title':        '⏰ تذكير — $typeLabel',
      'body':         '$assigneeName، عليك $typeLabel في "$activityName" يوم $dateKey',
      'scheduledFor': Timestamp.fromDate(reminderTime),
      'sent':         false,
      'createdAt':    FieldValue.serverTimestamp(),
    });
  }

  /// احذف إشعار معلّق لما التوزيع يتحذف
  Future<void> cancelScheduleNotification(String assignmentId) async {
    try {
      final snap = await _db
          .collection('pending_notifications')
          .where('assignmentId', isEqualTo: assignmentId)
          .where('sent', isEqualTo: false)
          .get();
      final batch = _db.batch();
      for (final d in snap.docs) batch.delete(d.reference);
      if (snap.docs.isNotEmpty) await batch.commit();
    } catch (_) {}
  }

  // ─── استقبال وهو مفتوح (foreground) ─────────────────────────────────────
  Future<void> _handleForeground(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    await _showNotification(
      id:    message.messageId?.hashCode.abs() ?? DateTime.now().millisecond,
      title: n.title ?? '',
      body:  n.body  ?? '',
    );
  }

  void _handleMessageOpened(RemoteMessage message) {
    // ممكن تعمل navigate هنا للشاشة المناسبة لو حبيت
  }

  // ─── عرض إشعار محلي (foreground) ────────────────────────────────────────
  Future<void> _showNotification({
    required int    id,
    required String title,
    required String body,
  }) async {
    await _notifPlugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  // ─── عرض إشعار من الـ background handler (static) ───────────────────────
  static Future<void> _showBackgroundNotification(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS:     DarwinInitializationSettings(),
    ));
    await plugin.show(
      message.messageId?.hashCode.abs() ?? DateTime.now().millisecond,
      n.title ?? '',
      n.body  ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'schedule_channel',
          'تذكير التوزيع',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
