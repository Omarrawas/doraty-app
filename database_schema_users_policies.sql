-- ============================================
-- سياسات جدول المستخدمين (public.users)
-- ============================================

-- تفعيل RLS على جدول المستخدمين (إذا لم يكن مفعلاً)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 1. سياسة القراءة (SELECT)
-- السماح لجميع المستخدمين المسجلين بقراءة بيانات المستخدمين (للعرض في القوائم والبروفايلات)
CREATE POLICY "Enable read access for authenticated users" 
ON public.users
FOR SELECT 
USING (auth.role() = 'authenticated');

-- 2. سياسة التعديل (UPDATE)
-- السماح للمستخدم بتعديل بياناته الشخصية + السماح للأدمن بتعديل أي مستخدم
CREATE POLICY "Enable update for users based on id or admin status" 
ON public.users
FOR UPDATE
USING (
  auth.uid() = id 
  OR 
  (SELECT is_admin()) -- استخدام دالة is_admin الآمنة التي أنشأناها سابقاً
);

-- ============================================
-- سياسات جدول أدوار المستخدمين (public.user_roles) - تحديث
-- ============================================

-- تأكد من وجود دالة is_admin
-- (تم إنشاؤها في ملف سابق، لكن نعيد تعريفها هنا للتأكد إذا لزم الأمر، أو نعتمد على وجودها)
-- نعتمد على وجودها من الملف السابق (supabase_fix_infinite_recursion.sql)

-- سياسات user_roles تم إعدادها في supabase_fix_infinite_recursion.sql
-- وهي:
-- 1. Admins can manage roles (FOR ALL)
-- 2. Users can view own roles (FOR SELECT)

-- سنضيف سياسة إضافية لضمان أن الأدمن يمكنه رؤية أدوار جميع المستخدمين (لصفحة إدارة المستخدمين)
-- السياسة الحالية: "Users can view own roles" تقيد الرؤية للشخص نفسه فقط.
-- نحتاج توسيعها أو إضافة سياسة جديدة للأدمن.

DROP POLICY IF EXISTS "Admins can view all roles" ON public.user_roles;

CREATE POLICY "Admins can view all roles" 
ON public.user_roles
FOR SELECT
USING ( is_admin() );

-- ============================================
-- سياسات إضافية مفيدة
-- ============================================

-- السماح للأدمن بحذف المستخدمين (إذا لزم الأمر)
CREATE POLICY "Admins can delete users" 
ON public.users
FOR DELETE
USING ( is_admin() );

