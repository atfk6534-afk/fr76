# إعداد Supabase للإشعارات — مجاني 100% بدون كارت

## الخطوة ١ — إنشاء حساب Supabase

1. افتح [supabase.com](https://supabase.com)
2. اضغط **Start your project** ← **Sign up**
3. سجّل بـ GitHub أو Google (أسرع)
4. اضغط **New project**
5. اختار أي اسم وأي كلمة سر وأي region
6. اضغط **Create new project** وستني دقيقتين

---

## الخطوة ٢ — جيب Service Account من Firebase

محتاج ملف فيه صلاحيات الوصول لـ Firebase من خارج التطبيق.

1. افتح [Firebase Console](https://console.firebase.google.com)
2. اختار مشروعك
3. اضغط ⚙️ **Project Settings** (الترس)
4. اختار تبويب **Service accounts**
5. اضغط **Generate new private key**
6. هينزل ملف JSON — **افتحه وسيبه جنبك**

---

## الخطوة ٣ — رفع الـ Edge Function

### أ — نزّل Supabase CLI

**Windows:**
افتح PowerShell واكتب:
```
winget install Supabase.CLI
```

لو مش شغال، حمّل مباشرة من:
https://github.com/supabase/cli/releases/latest
← اختار `supabase_windows_amd64.exe`
← غيّر اسمه لـ `supabase.exe` وحطه في `C:\Windows\System32`

**Mac:**
```
brew install supabase/tap/supabase
```

### ب — ادخل على مشروع Supabase

```bash
supabase login
```
هيطلب منك تروح للمتصفح وتسمح

```bash
supabase link --project-ref YOUR_PROJECT_REF
```
الـ `project-ref` هتلاقيه في Supabase Dashboard ← Settings ← General ← Reference ID

### ج — ارفع الـ Function

روح لمجلد التطبيق:
```bash
cd attendance_app_v15/supabase
supabase functions deploy send-notifications --no-verify-jwt
```

---

## الخطوة ٤ — أضف الـ Secrets (بيانات Firebase)

افتح ملف الـ JSON اللي نزلته من Firebase وجيب منه:
- `project_id`
- `client_email`
- `private_key`

في Supabase Dashboard:
1. اختار مشروعك ← **Edge Functions** ← **send-notifications**
2. اضغط **Secrets** أو من القايمة الجانبية **Settings** ← **Edge Functions**
3. أضف الـ secrets دي واحدة واحدة:

```
FIREBASE_PROJECT_ID     = (الـ project_id من الـ JSON)
FIREBASE_CLIENT_EMAIL   = (الـ client_email من الـ JSON)
FIREBASE_PRIVATE_KEY    = (الـ private_key من الـ JSON — انسخه كله حتى لو طويل)
```

---

## الخطوة ٥ — اعمل Cron Job كل دقيقة

في Supabase Dashboard:
1. من القايمة الشمال اختار **Database**
2. اختار **Extensions**
3. ابحث عن `pg_cron` وفعّله

بعدين اختار **SQL Editor** وشغّل:

```sql
select cron.schedule(
  'send-notifications-every-minute',
  '* * * * *',
  $$
  select net.http_post(
    url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-notifications',
    headers := '{"Authorization": "Bearer YOUR_ANON_KEY"}'::jsonb
  ) as request_id;
  $$
);
```

**غيّر:**
- `YOUR_PROJECT_REF` ← من Settings ← General ← Reference ID
- `YOUR_ANON_KEY` ← من Settings ← API ← anon public key

---

## الخطوة ٦ — Firestore Rules

في Firebase Console:
1. **Firestore Database** ← **Rules**
2. امسح كل الكود الموجود
3. انسخ محتوى ملف `firestore.rules` الصقه
4. اضغط **Publish**

---

## اختبار سريع

بعد ما تخلص كل الخطوات، جرّب تبعت إشعار تجريبي:

افتح أي browser وادخل على:
```
https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-notifications
```

لو ردّ بـ `{"sent":0}` يبقى شغّال ✅
لو ردّ بـ error يبقى فيه مشكلة في الـ secrets

---

## ملخص الأدوات المجانية

| الأداة | الاستخدام | المجاني |
|--------|-----------|---------|
| Supabase | Edge Function + Cron | مجاني للأبد |
| Firebase | Firestore + FCM | مجاني للأبد |
| Supabase pg_cron | كل دقيقة | مجاني |

---

## لو واجهتك أي مشكلة

قولي في أي خطوة وقفت وهساعدك.
