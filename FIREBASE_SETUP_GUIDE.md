# دليل إعداد Firebase الكامل

## الخطوات المطلوبة لتشغيل الإشعارات والمزامنة الصحيحة

---

## ١ — تفعيل Firebase Cloud Messaging

1. افتح [Firebase Console](https://console.firebase.google.com)
2. اختار مشروعك
3. اتجه لـ **Project Settings** ← **Cloud Messaging**
4. تأكد إن Cloud Messaging API (V1) **مفعّل**

---

## ٢ — نشر Firestore Security Rules

```bash
# من مجلد المشروع الرئيسي
firebase deploy --only firestore:rules
```

أو من Firebase Console:
1. **Firestore Database** ← **Rules**
2. انسخ محتوى `firestore.rules` والصقه
3. اضغط **Publish**

---

## ٣ — نشر Cloud Functions

```bash
cd cloud_functions/functions
npm install
npm run build

cd ..
firebase deploy --only functions
```

**الفانكشنز اللي هتتنشر:**
- `sendScheduledNotifications` — تعمل كل دقيقة، تبعت الإشعارات في وقتها
- `cleanupOldNotifications` — تعمل يومياً، تحذف الإشعارات القديمة
- `updateFcmToken` — Callable function لتحديث الـ token

> ⚠️ Cloud Functions تحتاج **Blaze plan** (Pay as you go)
> الاستخدام الخاص بك هيكون في الـ free tier — مش هتدفع حاجة عملياً

---

## ٤ — إعداد Cloud Scheduler

Cloud Functions الـ scheduler بتتفعّل تلقائياً لما تنشرها.
تأكد إن **Cloud Scheduler API** مفعّل في Google Cloud Console:

1. اتجه لـ [Google Cloud Console](https://console.cloud.google.com)
2. اختار مشروع Firebase بتاعك
3. ابحث عن **Cloud Scheduler API** وفعّله

---

## ٥ — إضافة google-services.json (لو مش موجود)

1. Firebase Console ← **Project Settings** ← **Your apps**
2. اختار تطبيق Android
3. حمّل `google-services.json`
4. حطه في `android/app/`

---

## ٦ — تأكيد إعداد Android للإشعارات

في `android/app/build.gradle`:
```gradle
android {
    defaultConfig {
        // تأكد إن minSdkVersion >= 21
        minSdkVersion 21
    }
}
```

في `android/app/src/main/AndroidManifest.xml` (موجود بالفعل في الكود):
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

---

## ٧ — اختبار الإشعارات

### اختبار يدوي من Firebase Console:
1. **Cloud Messaging** ← **Send your first message**
2. اكتب عنوان ورسالة
3. في **Target**: اختر **Single device** والصق الـ FCM token

### عشان تجيب الـ FCM token:
أضف مؤقتاً في الكود بعد `saveToken`:
```dart
final token = await FirebaseMessaging.instance.getToken();
print('FCM Token: $token');
```

---

## ٨ — كيف تشتغل الإشعارات

```
المدير يضيف توزيع
        ↓
ScheduleProvider.addAssignment()
        ↓
يحفظ في Firestore: pending_notifications
مع scheduledFor = وقت التذكير
        ↓
Cloud Function (كل دقيقة)
تفحص pending_notifications
        ↓
لو scheduledFor <= الوقت الحالي
تجيب FCM token الخادم من users collection
        ↓
تبعت FCM push notification
        ↓
الإشعار يوصل حتى لو التطبيق مغلق ✅
```

---

## ٩ — ضمان عدم عودة البيانات المحذوفة

المزامنة الآن بتستخدم `docChanges` بدل `snapshots`:
- `DocumentChangeType.removed` → يحذف من Hive نهائياً
- مفيش soft delete في الرحلات والتوزيع

لو بيانات محذوفة بترجع، السبب واحد من اتنين:
1. جهاز تاني عنده بيانات قديمة offline → هيتزامن أول ما يتصل ويشوف إنها مش في Firestore
2. Firestore Security Rules بتمنع الحذف → تأكد إن المدير عنده `allow delete`

---

## ملاحظات مهمة

- الإشعار بيوصل **حتى لو التطبيق مغلق** عبر FCM + Cloud Function
- الدقة: كل دقيقة (ممكن تتأخر دقيقة واحدة كحد أقصى)
- لو الجهاز offline: الإشعار هيوصل أول ما يتصل بالانترنت
- كل خادم يشوف إشعاراته هو بس (Firestore Rules)
