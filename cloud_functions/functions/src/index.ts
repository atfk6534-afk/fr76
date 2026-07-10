import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";

admin.initializeApp();

const db  = admin.firestore();
const fcm = admin.messaging();

// ─────────────────────────────────────────────────────────────────────────────
// Cloud Function 1: إرسال الإشعارات المجدوَلة
//
// تعمل كل دقيقة (Cloud Scheduler)
// تبحث في pending_notifications عن إشعارات حان وقتها
// وتبعت FCM push notification للجهاز المعني
// ─────────────────────────────────────────────────────────────────────────────
export const sendScheduledNotifications = functions.scheduler.onSchedule(
  {
    schedule:    "every 1 minutes",
    timeZone:    "Africa/Cairo",
    region:      "europe-west1",
    memory:      "256MiB",
  },
  async () => {
    const now  = admin.firestore.Timestamp.now();

    // جيب كل الإشعارات اللي حان وقتها ولم تُرسَل بعد
    const snap = await db
      .collection("pending_notifications")
      .where("sent", "==", false)
      .where("scheduledFor", "<=", now)
      .limit(100)
      .get();

    if (snap.empty) return;

    const batch  = db.batch();
    const errors: string[] = [];

    for (const doc of snap.docs) {
      const data = doc.data();
      const toUid: string = data.toUid;
      const title: string = data.title ?? "⏰ تذكير";
      const body:  string = data.body  ?? "";

      try {
        // جيب FCM token للمستخدم
        const userDoc = await db.collection("users").doc(toUid).get();
        const token: string | undefined = userDoc.data()?.fcmToken;

        if (token) {
          await fcm.send({
            token,
            notification: { title, body },
            android: {
              notification: {
                channelId:   "schedule_channel",
                priority:    "high",
                sound:       "default",
                icon:        "@mipmap/ic_launcher",
              },
              priority: "high",
            },
            apns: {
              payload: {
                aps: {
                  alert: { title, body },
                  sound: "default",
                  badge: 1,
                },
              },
            },
          });
        }

        // ضع علامة "تم الإرسال" بغض النظر عن وجود الـ token
        batch.update(doc.ref, {
          sent:   true,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      } catch (err) {
        errors.push(`${doc.id}: ${err}`);
        // لو الـ token انتهى (messaging/registration-token-not-registered)
        // احذف الـ token من الـ user document
        const errMsg = String(err);
        if (errMsg.includes("registration-token-not-registered") ||
            errMsg.includes("invalid-registration-token")) {
          batch.update(db.collection("users").doc(toUid), { fcmToken: "" });
        }
        // ضع علامة على الإشعار إنه فشل عشان ما يكررش
        batch.update(doc.ref, { sent: true, error: errMsg });
      }
    }

    await batch.commit();
    if (errors.length > 0) {
      console.error("FCM errors:", errors);
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// Cloud Function 2: تنظيف الإشعارات القديمة تلقائياً
//
// تعمل كل يوم الساعة 2 صباحاً
// تحذف الإشعارات اللي تم إرسالها من أكتر من 30 يوم
// ─────────────────────────────────────────────────────────────────────────────
export const cleanupOldNotifications = functions.scheduler.onSchedule(
  {
    schedule:  "0 2 * * *",   // كل يوم الساعة 2 صباحاً
    timeZone:  "Africa/Cairo",
    region:    "europe-west1",
    memory:    "256MiB",
  },
  async () => {
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - 30);

    const snap = await db
      .collection("pending_notifications")
      .where("sent", "==", true)
      .where("sentAt", "<=", admin.firestore.Timestamp.fromDate(cutoff))
      .limit(500)
      .get();

    if (snap.empty) return;

    const batch = db.batch();
    for (const doc of snap.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    console.log(`Deleted ${snap.size} old notifications`);
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// Cloud Function 3: تحديث FCM token لما يتجدد
// تُستدعى من التطبيق عبر Callable Function
// ─────────────────────────────────────────────────────────────────────────────
export const updateFcmToken = functions.https.onCall(
  { region: "europe-west1" },
  async (request) => {
    const uid   = request.auth?.uid;
    const token = request.data?.token as string | undefined;

    if (!uid || !token) {
      throw new functions.https.HttpsError("invalid-argument", "uid and token required");
    }

    await db.collection("users").doc(uid).update({ fcmToken: token });
    return { success: true };
  }
);
