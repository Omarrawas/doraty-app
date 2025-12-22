-- ============================================
-- إضافة عمود Bio لجدول المستخدمين
-- ============================================

-- إضافة عمود bio
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS bio TEXT NULL;

-- إضافة تعليق توضيحي للعمود
COMMENT ON COLUMN public.users.bio IS 'السيرة الذاتية للمدرس أو المستخدم';

-- ============================================
-- اختبار التحديث
-- ============================================

-- عرض بنية الجدول المحدثة
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'users' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- ============================================
-- بنية جدول users الكاملة بعد التحديث
-- ============================================

/*
الأعمدة الموجودة:
- id (UUID, NOT NULL, PRIMARY KEY)
- full_name (TEXT, NOT NULL)
- email (TEXT, NOT NULL, UNIQUE)
- avatar_url (TEXT, NULL)
- branch (TEXT, NULL) - CHECK: 'علمي' or 'أدبي'
- points (INTEGER, DEFAULT 0)
- level (INTEGER, DEFAULT 1)
- streak_days (INTEGER, DEFAULT 0)
- bio (TEXT, NULL) ← الجديد
- created_at (TIMESTAMP, DEFAULT NOW())
- updated_at (TIMESTAMP, DEFAULT NOW())
*/
