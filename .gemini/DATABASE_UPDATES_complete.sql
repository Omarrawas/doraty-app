-- ============================================
-- التعديلات المطلوبة على قاعدة البيانات
-- لإدارة الدورات والمدرسين
-- ============================================

-- ==========================================
-- 1. إضافة عمود Bio لجدول users
-- ==========================================

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS bio TEXT NULL;

COMMENT ON COLUMN public.users.bio IS 'السيرة الذاتية للمدرس أو المستخدم';


-- ==========================================
-- 2. إضافة عمود Branch لجدول courses
-- ==========================================

ALTER TABLE public.courses 
ADD COLUMN IF NOT EXISTS branch TEXT NULL;

-- إضافة constraint للتحقق من القيمة
ALTER TABLE public.courses
DROP CONSTRAINT IF EXISTS courses_branch_check;

ALTER TABLE public.courses
ADD CONSTRAINT courses_branch_check 
CHECK (branch IS NULL OR branch IN ('علمي', 'أدبي'));

COMMENT ON COLUMN public.courses.branch IS 'الفرع الدراسي للدورة: علمي أو أدبي';


-- ==========================================
-- 3. (اختياري) حذف instructor_id من courses
-- ==========================================

-- إذا كان موجود عمود instructor_id في جدول courses،
-- يفضل حذفه لأننا نستخدم teacher_courses بدلاً منه

ALTER TABLE public.courses 
DROP COLUMN IF EXISTS instructor_id;


-- ==========================================
-- 4. التأكد من صحة جدول teacher_courses
-- ==========================================

-- إنشاء الجدول إذا لم يكن موجوداً
CREATE TABLE IF NOT EXISTS public.teacher_courses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  teacher_id UUID NOT NULL,
  course_id UUID NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- إضافة foreign keys
ALTER TABLE public.teacher_courses
DROP CONSTRAINT IF EXISTS teacher_courses_teacher_id_fkey;

ALTER TABLE public.teacher_courses
ADD CONSTRAINT teacher_courses_teacher_id_fkey
FOREIGN KEY (teacher_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE public.teacher_courses
DROP CONSTRAINT IF EXISTS teacher_courses_course_id_fkey;

ALTER TABLE public.teacher_courses
ADD CONSTRAINT teacher_courses_course_id_fkey
FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;

-- إضافة unique constraint لمنع التكرار
ALTER TABLE public.teacher_courses
DROP CONSTRAINT IF EXISTS teacher_courses_unique;

ALTER TABLE public.teacher_courses
ADD CONSTRAINT teacher_courses_unique UNIQUE(teacher_id, course_id);

-- إنشاء indexes للأداء
CREATE INDEX IF NOT EXISTS idx_teacher_courses_teacher_id 
ON public.teacher_courses(teacher_id);

CREATE INDEX IF NOT EXISTS idx_teacher_courses_course_id 
ON public.teacher_courses(course_id);


-- ==========================================
-- 5. عرض بنية الجداول المحدثة
-- ==========================================

-- عرض أعمدة جدول users
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'users' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- عرض أعمدة جدول courses
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'courses' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- عرض أعمدة جدول teacher_courses
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'teacher_courses' 
AND table_schema = 'public'
ORDER BY ordinal_position;


-- ==========================================
-- 6. اختبار البيانات
-- ==========================================

-- عرض الدورات مع المدرسين
SELECT 
  c.id as course_id,
  c.title as course_title,
  c.branch as course_branch,
  c.is_published,
  u.id as teacher_id,
  u.full_name as teacher_name,
  u.bio as teacher_bio
FROM public.courses c
LEFT JOIN public.teacher_courses tc ON c.id = tc.course_id
LEFT JOIN public.users u ON tc.teacher_id = u.id
ORDER BY c.created_at DESC
LIMIT 10;


-- ==========================================
-- 7. تحديث دورة example (اختياري)
-- ==========================================

-- إذا كنت تريد تحديث دورة موجودة:
/*
UPDATE public.courses
SET branch = 'علمي'
WHERE title LIKE '%فيزياء%' OR title LIKE '%كيمياء%' OR title LIKE '%أحياء%';

UPDATE public.courses
SET branch = 'أدبي'
WHERE title LIKE '%عربي%' OR title LIKE '%تاريخ%' OR title LIKE '%جغرافيا%';
*/


-- ==========================================
-- النتيجة النهائية
-- ==========================================

/*
✅ جدول users:
  - id
  - full_name
  - email
  - avatar_url
  - branch (للمستخدم)
  - bio ← جديد
  - points
  - level
  - streak_days
  - created_at
  - updated_at

✅ جدول courses:
  - id
  - title
  - description
  - category
  - subject
  - branch ← جديد (علمي/أدبي)
  - is_published
  - created_at
  - updated_at

✅ جدول teacher_courses:
  - id
  - teacher_id (FK → users.id)
  - course_id (FK → courses.id)
  - created_at
  - updated_at
  - UNIQUE(teacher_id, course_id)
*/
