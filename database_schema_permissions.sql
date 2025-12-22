-- ============================================
-- نظام الصلاحيات والأدوار
-- ============================================

-- 1. جدول الأدوار (Roles)
CREATE TABLE public.roles (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  description TEXT NULL,
  created_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  
  CONSTRAINT roles_pkey PRIMARY KEY (id),
  CONSTRAINT roles_name_check CHECK (
    name = ANY (ARRAY[
      'student'::TEXT,
      'teacher'::TEXT,
      'admin'::TEXT,
      'super_admin'::TEXT
    ])
  )
);

-- 2. جدول الصلاحيات (Permissions)
CREATE TABLE public.permissions (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  description TEXT NULL,
  resource TEXT NOT NULL, -- exams, courses, users, etc.
  action TEXT NOT NULL, -- create, read, update, delete
  created_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  
  CONSTRAINT permissions_pkey PRIMARY KEY (id)
);

-- 3. جدول ربط الأدوار بالصلاحيات (Role Permissions)
CREATE TABLE public.role_permissions (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  role_id UUID NOT NULL,
  permission_id UUID NOT NULL,
  created_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  
  CONSTRAINT role_permissions_pkey PRIMARY KEY (id),
  CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) 
    REFERENCES roles(id) ON DELETE CASCADE,
  CONSTRAINT role_permissions_permission_id_fkey FOREIGN KEY (permission_id) 
    REFERENCES permissions(id) ON DELETE CASCADE,
  CONSTRAINT role_permissions_unique UNIQUE (role_id, permission_id)
);

-- 4. جدول أدوار المستخدمين (User Roles)
CREATE TABLE public.user_roles (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  user_id UUID NOT NULL,
  role_id UUID NOT NULL,
  assigned_by UUID NULL,
  assigned_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  
  CONSTRAINT user_roles_pkey PRIMARY KEY (id),
  CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) 
    REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT user_roles_role_id_fkey FOREIGN KEY (role_id) 
    REFERENCES roles(id) ON DELETE CASCADE,
  CONSTRAINT user_roles_assigned_by_fkey FOREIGN KEY (assigned_by) 
    REFERENCES auth.users(id) ON DELETE SET NULL,
  CONSTRAINT user_roles_unique UNIQUE (user_id, role_id)
);

-- 5. جدول ربط المدرسين بالدورات (Teacher Courses)
CREATE TABLE public.teacher_courses (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  teacher_id UUID NOT NULL,
  course_id UUID NOT NULL,
  assigned_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  
  CONSTRAINT teacher_courses_pkey PRIMARY KEY (id),
  CONSTRAINT teacher_courses_teacher_id_fkey FOREIGN KEY (teacher_id) 
    REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT teacher_courses_course_id_fkey FOREIGN KEY (course_id) 
    REFERENCES courses(id) ON DELETE CASCADE,
  CONSTRAINT teacher_courses_unique UNIQUE (teacher_id, course_id)
);

-- ============================================
-- الفهارس
-- ============================================

CREATE INDEX idx_user_roles_user_id ON public.user_roles(user_id);
CREATE INDEX idx_user_roles_role_id ON public.user_roles(role_id);
CREATE INDEX idx_role_permissions_role_id ON public.role_permissions(role_id);
CREATE INDEX idx_role_permissions_permission_id ON public.role_permissions(permission_id);
CREATE INDEX idx_teacher_courses_teacher_id ON public.teacher_courses(teacher_id);
CREATE INDEX idx_teacher_courses_course_id ON public.teacher_courses(course_id);

-- ============================================
-- تفعيل RLS
-- ============================================

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_courses ENABLE ROW LEVEL SECURITY;

-- ============================================
-- السياسات (RLS Policies)
-- ============================================

-- الجميع يمكنهم قراءة الأدوار
CREATE POLICY "Enable read for all users" ON public.roles
  FOR SELECT USING (true);

-- الجميع يمكنهم قراءة الصلاحيات
CREATE POLICY "Enable read for all users" ON public.permissions
  FOR SELECT USING (true);

-- المستخدمون يمكنهم رؤية أدوارهم
CREATE POLICY "Users can view own roles" ON public.user_roles
  FOR SELECT USING (auth.uid() = user_id);

-- الأدمن فقط يمكنهم تعيين الأدوار
CREATE POLICY "Admins can manage roles" ON public.user_roles
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM user_roles ur
      JOIN roles r ON ur.role_id = r.id
      WHERE ur.user_id = auth.uid()
      AND r.name IN ('admin', 'super_admin')
    )
  );

-- المدرسون يمكنهم رؤية دوراتهم
CREATE POLICY "Teachers can view own courses" ON public.teacher_courses
  FOR SELECT USING (auth.uid() = teacher_id);

-- الأدمن يمكنهم إدارة ربط المدرسين بالدورات
CREATE POLICY "Admins can manage teacher courses" ON public.teacher_courses
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM user_roles ur
      JOIN roles r ON ur.role_id = r.id
      WHERE ur.user_id = auth.uid()
      AND r.name IN ('admin', 'super_admin')
    )
  );

-- ============================================
-- إدخال البيانات الأساسية
-- ============================================

-- إضافة الأدوار الأساسية
INSERT INTO roles (name, display_name, description) VALUES
  ('student', 'طالب', 'دور الطالب العادي'),
  ('teacher', 'مدرس', 'دور المدرس/المعلم'),
  ('admin', 'مدير', 'دور المدير/الإداري'),
  ('super_admin', 'مدير عام', 'دور المدير العام للنظام');

-- إضافة الصلاحيات الأساسية

-- صلاحيات الاختبارات
INSERT INTO permissions (name, display_name, description, resource, action) VALUES
  ('exams.create', 'إنشاء اختبار', 'إنشاء اختبارات جديدة', 'exams', 'create'),
  ('exams.read', 'قراءة الاختبارات', 'عرض الاختبارات', 'exams', 'read'),
  ('exams.update', 'تعديل اختبار', 'تعديل الاختبارات الموجودة', 'exams', 'update'),
  ('exams.delete', 'حذف اختبار', 'حذف الاختبارات', 'exams', 'delete'),
  ('exams.publish', 'نشر اختبار', 'نشر الاختبارات للطلاب', 'exams', 'publish'),
  
  -- صلاحيات الأسئلة
  ('questions.create', 'إنشاء سؤال', 'إضافة أسئلة للاختبارات', 'questions', 'create'),
  ('questions.read', 'قراءة الأسئلة', 'عرض الأسئلة', 'questions', 'read'),
  ('questions.update', 'تعديل سؤال', 'تعديل الأسئلة', 'questions', 'update'),
  ('questions.delete', 'حذف سؤال', 'حذف الأسئلة', 'questions', 'delete'),
  
  -- صلاحيات النتائج
  ('results.view_all', 'عرض جميع النتائج', 'عرض نتائج جميع الطلاب', 'results', 'read'),
  ('results.view_own', 'عرض النتائج الشخصية', 'عرض النتائج الشخصية فقط', 'results', 'read'),
  ('results.grade', 'تصحيح الإجابات', 'تصحيح الأسئلة المقالية', 'results', 'update'),
  
  -- صلاحيات الدورات
  ('courses.create', 'إنشاء دورة', 'إنشاء دورات جديدة', 'courses', 'create'),
  ('courses.read', 'قراءة الدورات', 'عرض الدورات', 'courses', 'read'),
  ('courses.update', 'تعديل دورة', 'تعديل الدورات', 'courses', 'update'),
  ('courses.delete', 'حذف دورة', 'حذف الدورات', 'courses', 'delete'),
  
  -- صلاحيات المستخدمين
  ('users.create', 'إنشاء مستخدم', 'إضافة مستخدمين جدد', 'users', 'create'),
  ('users.read', 'قراءة المستخدمين', 'عرض المستخدمين', 'users', 'read'),
  ('users.update', 'تعديل مستخدم', 'تعديل بيانات المستخدمين', 'users', 'update'),
  ('users.delete', 'حذف مستخدم', 'حذف المستخدمين', 'users', 'delete'),
  ('users.assign_roles', 'تعيين الأدوار', 'تعيين أدوار للمستخدمين', 'users', 'update'),
  
  -- صلاحيات التقارير
  ('reports.view', 'عرض التقارير', 'عرض التقارير والإحصائيات', 'reports', 'read'),
  ('reports.export', 'تصدير التقارير', 'تصدير التقارير', 'reports', 'read');

-- ربط الصلاحيات بالأدوار

-- صلاحيات الطالب
INSERT INTO role_permissions (role_id, permission_id)
SELECT 
  (SELECT id FROM roles WHERE name = 'student'),
  id
FROM permissions
WHERE name IN (
  'exams.read',
  'results.view_own',
  'courses.read'
);

-- صلاحيات المدرس
INSERT INTO role_permissions (role_id, permission_id)
SELECT 
  (SELECT id FROM roles WHERE name = 'teacher'),
  id
FROM permissions
WHERE name IN (
  'exams.create',
  'exams.read',
  'exams.update',
  'exams.delete',
  'exams.publish',
  'questions.create',
  'questions.read',
  'questions.update',
  'questions.delete',
  'results.view_all',
  'results.grade',
  'courses.read',
  'reports.view',
  'reports.export'
);

-- صلاحيات المدير
INSERT INTO role_permissions (role_id, permission_id)
SELECT 
  (SELECT id FROM roles WHERE name = 'admin'),
  id
FROM permissions
WHERE name IN (
  'exams.create',
  'exams.read',
  'exams.update',
  'exams.delete',
  'exams.publish',
  'questions.create',
  'questions.read',
  'questions.update',
  'questions.delete',
  'results.view_all',
  'results.grade',
  'courses.create',
  'courses.read',
  'courses.update',
  'courses.delete',
  'users.create',
  'users.read',
  'users.update',
  'users.assign_roles',
  'reports.view',
  'reports.export'
);

-- صلاحيات المدير العام (جميع الصلاحيات)
INSERT INTO role_permissions (role_id, permission_id)
SELECT 
  (SELECT id FROM roles WHERE name = 'super_admin'),
  id
FROM permissions;

-- ============================================
-- دوال مساعدة
-- ============================================

-- دالة للتحقق من صلاحية المستخدم
CREATE OR REPLACE FUNCTION has_permission(
  user_id_param UUID,
  permission_name_param TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM user_roles ur
    JOIN role_permissions rp ON ur.role_id = rp.role_id
    JOIN permissions p ON rp.permission_id = p.id
    WHERE ur.user_id = user_id_param
    AND p.name = permission_name_param
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة للحصول على دور المستخدم
CREATE OR REPLACE FUNCTION get_user_role(user_id_param UUID)
RETURNS TEXT AS $$
DECLARE
  user_role TEXT;
BEGIN
  SELECT r.name INTO user_role
  FROM user_roles ur
  JOIN roles r ON ur.role_id = r.id
  WHERE ur.user_id = user_id_param
  ORDER BY 
    CASE r.name
      WHEN 'super_admin' THEN 1
      WHEN 'admin' THEN 2
      WHEN 'teacher' THEN 3
      WHEN 'student' THEN 4
    END
  LIMIT 1;
  
  RETURN COALESCE(user_role, 'student');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة للتحقق من كون المستخدم مدرساً لدورة معينة
CREATE OR REPLACE FUNCTION is_teacher_of_course(
  user_id_param UUID,
  course_id_param UUID
)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM teacher_courses
    WHERE teacher_id = user_id_param
    AND course_id = course_id_param
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة للحصول على دورات المدرس
CREATE OR REPLACE FUNCTION get_teacher_courses(teacher_id_param UUID)
RETURNS TABLE (
  course_id UUID,
  course_title TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT c.id, c.title
  FROM teacher_courses tc
  JOIN courses c ON tc.course_id = c.id
  WHERE tc.teacher_id = teacher_id_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- تحديث سياسات الاختبارات للمدرسين
-- ============================================

-- حذف السياسات القديمة
DROP POLICY IF EXISTS "المدرسون يمكنهم إدارة الاختبارات" ON public.exams;
DROP POLICY IF EXISTS "المدرسون يمكنهم إدارة الأسئلة" ON public.questions;

-- سياسات جديدة للمدرسين
CREATE POLICY "Teachers can manage own course exams" ON public.exams
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM teacher_courses tc
      WHERE tc.teacher_id = auth.uid()
      AND tc.course_id = exams.course_id
    )
    OR
    EXISTS (
      SELECT 1 FROM user_roles ur
      JOIN roles r ON ur.role_id = r.id
      WHERE ur.user_id = auth.uid()
      AND r.name IN ('admin', 'super_admin')
    )
  );

CREATE POLICY "Teachers can manage own exam questions" ON public.questions
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM exams e
      JOIN teacher_courses tc ON e.course_id = tc.course_id
      WHERE e.id = questions.exam_id
      AND tc.teacher_id = auth.uid()
    )
    OR
    EXISTS (
      SELECT 1 FROM user_roles ur
      JOIN roles r ON ur.role_id = r.id
      WHERE ur.user_id = auth.uid()
      AND r.name IN ('admin', 'super_admin')
    )
  );

-- ============================================
-- بيانات تجريبية (اختياري)
-- ============================================

-- مثال: تعيين دور مدرس لمستخدم
/*
INSERT INTO user_roles (user_id, role_id)
VALUES (
  'USER_ID_HERE',
  (SELECT id FROM roles WHERE name = 'teacher')
);

-- ربط المدرس بدورة
INSERT INTO teacher_courses (teacher_id, course_id)
VALUES (
  'TEACHER_ID_HERE',
  'COURSE_ID_HERE'
);
*/

-- ============================================
-- استعلامات مفيدة للتحقق
-- ============================================

-- عرض جميع الأدوار مع صلاحياتها
/*
SELECT 
  r.display_name as role,
  p.display_name as permission,
  p.resource,
  p.action
FROM roles r
JOIN role_permissions rp ON r.id = rp.role_id
JOIN permissions p ON rp.permission_id = p.id
ORDER BY r.name, p.resource, p.action;
*/

-- عرض أدوار مستخدم معين
/*
SELECT 
  u.email,
  r.display_name as role
FROM auth.users u
JOIN user_roles ur ON u.id = ur.user_id
JOIN roles r ON ur.role_id = r.id
WHERE u.id = 'USER_ID_HERE';
*/

-- عرض دورات مدرس معين
/*
SELECT 
  u.email as teacher,
  c.title as course
FROM auth.users u
JOIN teacher_courses tc ON u.id = tc.teacher_id
JOIN courses c ON tc.course_id = c.id
WHERE u.id = 'TEACHER_ID_HERE';
*/
