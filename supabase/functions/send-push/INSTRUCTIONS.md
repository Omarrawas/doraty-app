# إعداد نظام إرسال الإشعارات (Push Notifications)

لقد تم إنشاء كود "Edge Function" جاهز لإرسال الإشعارات تلقائياً عند إضافة سجل جديد في جدول `admin_notifications`.

لإكمال التفعيل، اتبع الخطوات التالية:

## 1. الحصول على مفتاح Firebase (Service Account)

1. اذهب إلى [Firebase Console](https://console.firebase.google.com/).
2. اختر مشروعك.
3. اذهب إلى **Project Settings** > **Service accounts**.
4. اضغط على **Generate new private key**.
5. سيتم تحميل ملف JSON. افتحه وانسخ محتواه بالكامل.
6. **هام:** قم بإزالة جميع العلامات الجديدة (Newlines) ليصبح النص في سطر واحد (Minified JSON)، لأننا سنضعه في متغير بيئة.

## 2. إعداد Supabase Secrets

استخدم Supabase CLI أو لوحة التحكم (Dashboard) لإضافة المتغير:

1. من لوحة تحكم Supabase، اذهب إلى **Settings** > **Edge Functions**.
2. أضف سراً جديداً (New Secret):
   - الاسم: `FIREBASE_SERVICE_ACCOUNT`
   - القيمة: (ألصق محتوى ملف JSON الذي نسخته في الخطوة السابقة).

## 3. نشر الدالة (Deploy)

إذا كان لديك Supabase CLI مثبتاً، نفذ الأمر التالي في مجلد المشروع:

```bash
supabase functions deploy send-push --no-verify-jwt
```

## 4. ربط الدالة بقاعدة البيانات (Webhook)

لجعل الدالة تعمل تلقائياً عند إضافة إشعار جديد:

1. اذهب إلى **Database** > **Webhooks** في Supabase Dashboard.
2. اضغط **Create Webhook**.
3. الإعدادات:
   - **Name**: `admin-send-push`
   - **Table**: `public.admin_notifications`
   - **Events**: فعل خيار **INSERT**.
   - **Type**: `HTTP Request`.
   - **HTTP Method**: `POST`.
   - **URL**: (رابط الدالة التي نشرتها، تجده في صفحة Edge Functions).
   - **Headers**:
     - `Authorization`: `Bearer YOUR_SUPABASE_ANON_KEY` (أو Service Role Key).

الآن، بمجرد استخدامك لشاشة "إدارة الإشعارات" في لوحة تحكم الأدمن والضغط على "إرسال"، سيتم تشغيل هذه الوظيفة وإرسال الإشعار فعلياً للمستخدمين!
