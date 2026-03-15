-- ==============================================================================
-- DORATY DATABASE COMPLETE SCHEMA (MERGED)
-- ==============================================================================
-- This file contains the complete database structure, including tables, 
-- indexes, policies, functions, and triggers.
-- 
-- ORDER OF EXECUTION:
-- 1. Extensions & Core Tables
-- 2. Module Tables (Permissions, Orders, Exams, etc)
-- 3. Views & Indexes
-- 4. RLS Policies
-- 5. Functions & Triggers
-- ==============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- For search capabilities

-- ============================================
-- 1. CORE TABLES (Reconstructed)
-- ============================================

-- 1.1 USERS PROFILE (Handling public.users linked to auth.users)
CREATE TABLE IF NOT EXISTS public.users (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    full_name TEXT,
    email TEXT,
    avatar_url TEXT,
    bio TEXT,
    branch TEXT, -- Found in rpc functions
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 1.2 CATEGORIES
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    icon TEXT, -- URL or icon name
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 1.3 COURSES
CREATE TABLE IF NOT EXISTS public.courses (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    instructor_id UUID REFERENCES public.users(id),
    category_id UUID REFERENCES public.categories(id),
    image_url TEXT,
    thumbnail TEXT, -- Legacy support
    price DECIMAL(10, 2) DEFAULT 0,
    currency TEXT DEFAULT 'SYP',
    rating DECIMAL(3, 2) DEFAULT 0,
    status TEXT DEFAULT 'draft', -- published, draft, archived
    is_published BOOLEAN DEFAULT false,
    level TEXT,
    subject TEXT,
    curriculum JSONB, -- Or TEXT[]
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    -- Note: students_count, is_featured, featured_order added by migration script later
);

-- 1.4 LESSONS
CREATE TABLE IF NOT EXISTS public.lessons (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    course_id UUID REFERENCES public.courses(id) ON DELETE CASCADE,
    chapter_id UUID, -- Optional grouping
    title TEXT NOT NULL,
    description TEXT,
    video_url TEXT,
    duration TEXT, -- Stores "00:00" format
    order_index INTEGER DEFAULT 0,
    is_free BOOLEAN DEFAULT false,
    content_type TEXT DEFAULT 'video',
    resources JSONB,
    content_html TEXT,
    content_markdown TEXT,
    interactive_elements JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 1.5 COURSE STUDENTS (Legacy/Main Enrollment Table)
-- Referenced heavily in database_functions.sql
CREATE TABLE IF NOT EXISTS public.course_students (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    course_id UUID REFERENCES public.courses(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'enrolled',
    enrolled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(course_id, user_id)
);

-- 1.6 LESSON PROGRESS
CREATE TABLE IF NOT EXISTS public.lesson_progress (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    lesson_id UUID REFERENCES public.lessons(id) ON DELETE CASCADE,
    is_completed BOOLEAN DEFAULT false,
    watch_time INTEGER DEFAULT 0,
    last_position INTEGER DEFAULT 0,
    progress DECIMAL(5,2) DEFAULT 0, -- 0-1 or 0-100
    completed_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, lesson_id)
);

-- 1.7 NOTIFICATIONS
-- Referenced in database_functions_additional.sql
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT,
    type TEXT,
    category TEXT,
    data JSONB,
    is_read BOOLEAN DEFAULT false,
    action_url TEXT,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 2. APPLYING PROJECT MODULES
-- ============================================

-- Inserting content from database_schema_permissions.sql
-- ============================================
-- نظام الصلاحيات والأدوار
-- ============================================

-- 1. جدول الأدوار (Roles)
CREATE TABLE IF NOT EXISTS public.roles (
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
CREATE TABLE IF NOT EXISTS public.permissions (
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
CREATE TABLE IF NOT EXISTS public.role_permissions (
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
CREATE TABLE IF NOT EXISTS public.user_roles (
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
CREATE TABLE IF NOT EXISTS public.teacher_courses (
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

-- Creating Indexes for Permissions
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON public.user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role_id ON public.user_roles(role_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_role_id ON public.role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_permission_id ON public.role_permissions(permission_id);
CREATE INDEX IF NOT EXISTS idx_teacher_courses_teacher_id ON public.teacher_courses(teacher_id);
CREATE INDEX IF NOT EXISTS idx_teacher_courses_course_id ON public.teacher_courses(course_id);

-- Inserting content from database_schema_orders.sql
CREATE TABLE IF NOT EXISTS public.subscription_plans (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT NULL,
  price DECIMAL(10,2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'SYP',
  duration_months INTEGER NOT NULL DEFAULT 1,
  is_popular BOOLEAN NOT NULL DEFAULT false,
  features JSONB NULL,
  max_courses INTEGER NULL,
  max_downloads INTEGER NULL,
  has_offline_access BOOLEAN NOT NULL DEFAULT false,
  has_live_classes BOOLEAN NOT NULL DEFAULT false,
  has_exam_access BOOLEAN NOT NULL DEFAULT true,
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  CONSTRAINT subscription_plans_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.orders (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  user_id UUID NOT NULL,
  order_number TEXT NOT NULL UNIQUE,
  order_type TEXT NOT NULL DEFAULT 'subscription',
  status TEXT NOT NULL DEFAULT 'pending',
  total_amount DECIMAL(10,2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'SYP',
  payment_method TEXT NULL,
  payment_status TEXT NOT NULL DEFAULT 'pending',
  payment_transaction_id TEXT NULL,
  discount_code TEXT NULL,
  discount_amount DECIMAL(10,2) NULL DEFAULT 0,
  tax_amount DECIMAL(10,2) NULL DEFAULT 0,
  notes TEXT NULL,
  billing_address JSONB NULL,
  shipping_address JSONB NULL,
  ordered_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
  paid_at TIMESTAMP WITHOUT TIME ZONE NULL,
  confirmed_at TIMESTAMP WITHOUT TIME ZONE NULL,
  cancelled_at TIMESTAMP WITHOUT TIME ZONE NULL,
  refunded_at TIMESTAMP WITHOUT TIME ZONE NULL,
  expires_at TIMESTAMP WITHOUT TIME ZONE NULL,
  created_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  CONSTRAINT orders_pkey PRIMARY KEY (id),
  CONSTRAINT orders_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.order_items (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  order_id UUID NOT NULL,
  item_type TEXT NOT NULL,
  item_id UUID NOT NULL,
  item_name TEXT NOT NULL,
  item_description TEXT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price DECIMAL(10,2) NOT NULL,
  total_price DECIMAL(10,2) NOT NULL,
  discount_amount DECIMAL(10,2) NULL DEFAULT 0,
  start_date DATE NULL,
  end_date DATE NULL,
  features JSONB NULL,
  created_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  CONSTRAINT order_items_pkey PRIMARY KEY (id),
  CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.order_payments (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  order_id UUID NOT NULL,
  payment_method TEXT NOT NULL,
  payment_provider TEXT NULL,
  transaction_id TEXT NULL,
  payment_intent_id TEXT NULL,
  amount DECIMAL(10,2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'SYP',
  status TEXT NOT NULL DEFAULT 'pending',
  payment_date TIMESTAMP WITHOUT TIME ZONE NULL,
  failure_reason TEXT NULL,
  refund_amount DECIMAL(10,2) NULL DEFAULT 0,
  refund_reason TEXT NULL,
  created_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  CONSTRAINT order_payments_pkey PRIMARY KEY (id),
  CONSTRAINT order_payments_order_id_fkey FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.user_subscriptions (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  user_id UUID NOT NULL,
  order_id UUID NOT NULL,
  subscription_plan_id UUID NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  auto_renew BOOLEAN NOT NULL DEFAULT true,
  last_renewal_date DATE NULL,
  next_renewal_date DATE NULL,
  usage_stats JSONB NULL,
  max_courses INTEGER NULL,
  max_downloads INTEGER NULL,
  features JSONB NULL,
  created_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  CONSTRAINT user_subscriptions_pkey PRIMARY KEY (id),
  CONSTRAINT user_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.discount_codes (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT NULL,
  discount_type TEXT NOT NULL,
  discount_value DECIMAL(10,2) NOT NULL,
  min_order_amount DECIMAL(10,2) NULL DEFAULT 0,
  max_uses INTEGER NULL,
  used_count INTEGER NOT NULL DEFAULT 0,
  valid_from TIMESTAMP WITHOUT TIME ZONE NOT NULL,
  valid_until TIMESTAMP WITHOUT TIME ZONE NOT NULL,
  applicable_to TEXT NULL,
  applicable_ids UUID[] NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  CONSTRAINT discount_codes_pkey PRIMARY KEY (id)
);

-- Inserting content from database_schema_exams.sql
CREATE TABLE IF NOT EXISTS public.exams (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  course_id UUID NOT NULL,
  title TEXT NOT NULL,
  description TEXT NULL,
  duration INTEGER NOT NULL,
  total_points INTEGER NOT NULL DEFAULT 100,
  passing_score INTEGER NOT NULL DEFAULT 60,
  is_published BOOLEAN NOT NULL DEFAULT false,
  start_time TIMESTAMP NULL,
  end_time TIMESTAMP NULL,
  max_attempts INTEGER NULL DEFAULT 3,
  show_results_immediately BOOLEAN NOT NULL DEFAULT true,
  shuffle_questions BOOLEAN NOT NULL DEFAULT false,
  shuffle_options BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  CONSTRAINT exams_pkey PRIMARY KEY (id),
  CONSTRAINT exams_course_id_fkey FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.questions (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  exam_id UUID NOT NULL,
  question_text TEXT NOT NULL,
  question_type TEXT NOT NULL DEFAULT 'multiple_choice',
  options JSONB NULL,
  correct_answer JSONB NOT NULL,
  explanation TEXT NULL,
  points INTEGER NOT NULL DEFAULT 1,
  order_index INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  CONSTRAINT questions_pkey PRIMARY KEY (id),
  CONSTRAINT questions_exam_id_fkey FOREIGN KEY (exam_id) REFERENCES exams(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.exam_attempts (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  exam_id UUID NOT NULL,
  user_id UUID NOT NULL,
  started_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
  submitted_at TIMESTAMP WITHOUT TIME ZONE NULL,
  score INTEGER NULL,
  total_points INTEGER NOT NULL,
  percentage DECIMAL(5,2) NULL,
  is_passed BOOLEAN NULL,
  time_taken INTEGER NULL,
  attempt_number INTEGER NOT NULL DEFAULT 1,
  status TEXT NOT NULL DEFAULT 'in_progress',
  CONSTRAINT exam_attempts_pkey PRIMARY KEY (id),
  CONSTRAINT exam_attempts_exam_id_fkey FOREIGN KEY (exam_id) REFERENCES exams(id) ON DELETE CASCADE,
  CONSTRAINT exam_attempts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.exam_answers (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  attempt_id UUID NOT NULL,
  question_id UUID NOT NULL,
  user_answer JSONB NULL,
  is_correct BOOLEAN NULL,
  points_earned INTEGER NULL DEFAULT 0,
  answered_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  CONSTRAINT exam_answers_pkey PRIMARY KEY (id),
  CONSTRAINT exam_answers_attempt_id_fkey FOREIGN KEY (attempt_id) REFERENCES exam_attempts(id) ON DELETE CASCADE,
  CONSTRAINT exam_answers_question_id_fkey FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE,
  CONSTRAINT exam_answers_unique UNIQUE (attempt_id, question_id)
);

-- Inserting content from database_payment_receipts.sql
CREATE TABLE IF NOT EXISTS public.payment_accounts (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  payment_method TEXT NOT NULL,
  account_name TEXT NOT NULL,
  account_number TEXT NOT NULL,
  account_details JSONB NULL,
  instructions TEXT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  display_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  CONSTRAINT payment_accounts_pkey PRIMARY KEY (id),
  CONSTRAINT payment_accounts_method_unique UNIQUE (payment_method)
);

CREATE TABLE IF NOT EXISTS public.payment_receipts (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  order_id UUID NOT NULL,
  user_id UUID NOT NULL,
  payment_method TEXT NOT NULL,
  transaction_id TEXT NULL,
  receipt_image_url TEXT NULL,
  phone_number TEXT NULL,
  amount DECIMAL(10,2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  admin_notes TEXT NULL,
  reviewed_by UUID NULL,
  reviewed_at TIMESTAMP WITHOUT TIME ZONE NULL,
  created_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  CONSTRAINT payment_receipts_pkey PRIMARY KEY (id),
  CONSTRAINT payment_receipts_order_fkey FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  CONSTRAINT payment_receipts_user_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Redundant Enrollments table from Payment Receipts (Aliased/Linked to Course Students logic)
-- Note: Often projects drift to use 'enrollments'. We create it here to match script source.
CREATE TABLE IF NOT EXISTS public.enrollments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'active',
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Added by migration script
    completed_lessons INT DEFAULT 0,
    total_lessons INT DEFAULT 0,
    progress_percentage DECIMAL(5,2) DEFAULT 0.00,
    last_accessed_lesson_id UUID REFERENCES lessons(id)
);
-- Ensure unique constraint on enrollments
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'enrollments_user_id_course_id_key') THEN
        ALTER TABLE public.enrollments ADD CONSTRAINT enrollments_user_id_course_id_key UNIQUE(user_id, course_id);
    END IF;
END $$;

-- ============================================
-- 3. MIGRATIONS & UPDATES
-- ============================================

-- Applying add_dynamic_progress_featured.sql columns
-- (Using DO blocks to safely add if missing)
DO $$
BEGIN
    -- Courses columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='courses' AND column_name='students_count') THEN
        ALTER TABLE courses ADD COLUMN students_count INT DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='courses' AND column_name='is_featured') THEN
        ALTER TABLE courses ADD COLUMN is_featured BOOLEAN DEFAULT FALSE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='courses' AND column_name='featured_order') THEN
        ALTER TABLE courses ADD COLUMN featured_order INT DEFAULT 0;
    END IF;
END $$;

-- ============================================
-- 4. FUNCTIONS & TRIGGERS (CORE)
-- ============================================

-- Function to update course student count
CREATE OR REPLACE FUNCTION update_course_student_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE courses 
    SET students_count = students_count + 1 
    WHERE id = NEW.course_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE courses 
    SET students_count = GREATEST(students_count - 1, 0) 
    WHERE id = OLD.course_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger for student count (Attach to both course_students and enrollments to be safe)
DROP TRIGGER IF EXISTS enrollments_count_trigger ON enrollments;
CREATE TRIGGER enrollments_count_trigger
AFTER INSERT OR DELETE ON enrollments
FOR EACH ROW EXECUTE FUNCTION update_course_student_count();

DROP TRIGGER IF EXISTS course_students_count_trigger ON course_students;
CREATE TRIGGER course_students_count_trigger
AFTER INSERT OR DELETE ON course_students
FOR EACH ROW EXECUTE FUNCTION update_course_student_count();

-- Function to update enrollment progress
CREATE OR REPLACE FUNCTION update_enrollment_progress(
  p_enrollment_id UUID,
  p_course_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_total_lessons INT;
  v_completed_lessons INT;
  v_user_id UUID;
BEGIN
  -- Handle both tables (checking enrollments first)
  IF EXISTS (SELECT 1 FROM enrollments WHERE id = p_enrollment_id) THEN
      SELECT user_id INTO v_user_id FROM enrollments WHERE id = p_enrollment_id;
  ELSE
      SELECT user_id INTO v_user_id FROM course_students WHERE id = p_enrollment_id;
  END IF;

  SELECT COUNT(*) INTO v_total_lessons FROM lessons WHERE course_id = p_course_id;
  
  -- Progress calculation logic
  SELECT COUNT(DISTINCT lp.lesson_id) INTO v_completed_lessons
  FROM lesson_progress lp
  JOIN lessons l ON lp.lesson_id = l.id
  WHERE lp.user_id = v_user_id 
    AND l.course_id = p_course_id 
    AND lp.is_completed = TRUE;
  
  -- Update Enrollments
  UPDATE enrollments
  SET 
    total_lessons = v_total_lessons,
    completed_lessons = v_completed_lessons,
    progress_percentage = CASE 
      WHEN v_total_lessons > 0 THEN ROUND((v_completed_lessons::DECIMAL / v_total_lessons) * 100, 2)
      ELSE 0
    END
  WHERE id = p_enrollment_id;

  -- Logic for course_students (if columns exist - usually don't, skipping for course_students table)
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 5. FUNCTION MODULES (MERGED)
-- ============================================

-- From database_schema_teachers_rpc.sql
-- Function to get all teachers securely (bypassing RLS for public listing)
CREATE OR REPLACE FUNCTION get_all_teachers_public()
RETURNS TABLE (
  user_id UUID,
  name TEXT,
  email TEXT,
  avatar_url TEXT,
  branch TEXT,
  bio TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id as user_id, 
    u.full_name as name, 
    u.email,
    u.avatar_url, 
    u.branch,
    u.bio
  FROM users u
  JOIN user_roles ur ON u.id = ur.user_id
  JOIN roles r ON ur.role_id = r.id
  WHERE r.name = 'teacher';
END;
$$;

-- From database_functions.sql

-- دالة للتحقق من صلاحية المستخدم (محدثة)
CREATE OR REPLACE FUNCTION is_valid_user(user_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS(
    SELECT 1 FROM auth.users 
    WHERE id = user_uuid AND email_confirmed_at IS NOT NULL
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة للتحقق من صلاحية الأدمن
CREATE OR REPLACE FUNCTION is_admin(user_uuid UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS(
    SELECT 1 FROM public.users u
    JOIN public.user_roles ur ON u.id = ur.user_id
    JOIN public.roles r ON ur.role_id = r.id
    WHERE u.id = user_uuid AND r.name = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة للتحقق من صلاحية المدرس
CREATE OR REPLACE FUNCTION is_teacher(user_uuid UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS(
    SELECT 1 FROM public.users u
    JOIN public.user_roles ur ON u.id = ur.user_id
    JOIN public.roles r ON ur.role_id = r.id
    WHERE u.id = user_uuid AND r.name = 'teacher'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة للحصول على دور المستخدم
CREATE OR REPLACE FUNCTION get_user_role(user_uuid UUID DEFAULT auth.uid())
RETURNS TEXT AS $$
DECLARE
  user_role TEXT;
BEGIN
  SELECT r.name INTO user_role
  FROM public.users u
  JOIN public.user_roles ur ON u.id = ur.user_id
  JOIN public.roles r ON ur.role_id = r.id
  WHERE u.id = user_uuid;
  
  RETURN COALESCE(user_role, 'student');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة لإنشاء مستخدم جديد مع الدور الافتراضي
CREATE OR REPLACE FUNCTION create_user_with_role(
  user_uuid UUID,
  full_name TEXT,
  email TEXT,
  role_name TEXT DEFAULT 'student'
)
RETURNS BOOLEAN AS $$
DECLARE
  role_id UUID;
BEGIN
  -- التحقق من وجود الدور
  SELECT id INTO role_id FROM public.roles WHERE name = role_name;
  
  IF role_id IS NULL THEN
    RAISE EXCEPTION 'Role % does not exist', role_name;
  END IF;
  
  -- إنشاء المستخدم
  INSERT INTO public.users (id, full_name, email, created_at, updated_at)
  VALUES (user_uuid, full_name, email, NOW(), NOW())
  ON CONFLICT (id) DO NOTHING; -- Avoid error if user already exists
  
  -- إضافة الدور
  INSERT INTO public.user_roles (user_id, role_id, created_at)
  VALUES (user_uuid, role_id, NOW())
  ON CONFLICT (user_id, role_id) DO NOTHING;
  
  RETURN TRUE;
EXCEPTION
  WHEN unique_violation THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة للحصول على كورسات المدرس
CREATE OR REPLACE FUNCTION get_teacher_courses(teacher_uuid UUID DEFAULT auth.uid())
RETURNS TABLE (
  course_id UUID,
  course_name TEXT,
  category_name TEXT,
  total_lessons BIGINT,
  total_students BIGINT,
  course_status TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id as course_id,
    c.title as course_name,
    cat.name as category_name,
    COUNT(l.id) as total_lessons,
    COUNT(cs.user_id) as total_students,
    c.status as course_status
  FROM courses c
  JOIN categories cat ON c.category_id = cat.id
  LEFT JOIN lessons l ON c.id = l.course_id
  LEFT JOIN course_students cs ON c.id = cs.course_id AND cs.status = 'enrolled'
  WHERE c.instructor_id = teacher_uuid
  GROUP BY c.id, c.title, cat.name, c.status
  ORDER BY c.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة للتحقق من تسجيل الطالب في الكورس
CREATE OR REPLACE FUNCTION is_enrolled_in_course(
  user_uuid UUID,
  course_uuid UUID
)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS(
    SELECT 1 FROM course_students 
    WHERE user_id = user_uuid 
      AND course_id = course_uuid 
      AND status = 'enrolled'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة للحصول على تقدم الطالب في الكورس
CREATE OR REPLACE FUNCTION get_course_progress(
  user_uuid UUID,
  course_uuid UUID
)
RETURNS TABLE (
  total_lessons BIGINT,
  completed_lessons BIGINT,
  progress_percentage DECIMAL
) AS $$
DECLARE
  total_lesson_count BIGINT;
  completed_lesson_count BIGINT;
BEGIN
  -- عدد الدروس الإجمالي
  SELECT COUNT(*) INTO total_lesson_count
  FROM lessons
  WHERE course_id = course_uuid;
  
  -- عدد الدروس المكتملة
  SELECT COUNT(*) INTO completed_lesson_count
  FROM lesson_progress lp
  JOIN lessons l ON lp.lesson_id = l.id
  WHERE lp.user_id = user_uuid 
    AND l.course_id = course_uuid 
    AND lp.is_completed = true;
  
  RETURN QUERY SELECT 
    total_lesson_count,
    completed_lesson_count,
    CASE 
      WHEN total_lesson_count > 0 
      THEN ROUND((completed_lesson_count::DECIMAL / total_lesson_count::DECIMAL) * 100, 2)
      ELSE 0 
    END as progress_percentage;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة لتحديث تقدم الدرس
CREATE OR REPLACE FUNCTION update_lesson_progress(
  user_uuid UUID,
  lesson_uuid UUID,
  progress_value DECIMAL,
  is_completed BOOLEAN DEFAULT false
)
RETURNS BOOLEAN AS $$
BEGIN
  INSERT INTO lesson_progress (
    user_id, 
    lesson_id, 
    progress, 
    is_completed, 
    updated_at
  )
  VALUES (
    user_uuid, 
    lesson_uuid, 
    progress_value, 
    is_completed, 
    NOW()
  )
  ON CONFLICT (user_id, lesson_id) 
  DO UPDATE SET
    progress = EXCLUDED.progress,
    is_completed = EXCLUDED.is_completed,
    updated_at = NOW();
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة للحصول على محاولات الاختبار للطالب
CREATE OR REPLACE FUNCTION get_user_exam_attempts(
  user_uuid UUID,
  exam_uuid UUID
)
RETURNS TABLE (
  attempt_id UUID,
  attempt_number INTEGER,
  score INTEGER,
  percentage DECIMAL,
  is_passed BOOLEAN,
  time_taken INTEGER,
  started_at TIMESTAMP,
  submitted_at TIMESTAMP,
  status TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ea.id as attempt_id,
    ea.attempt_number,
    ea.score,
    ea.percentage,
    ea.is_passed,
    ea.time_taken,
    ea.started_at,
    ea.submitted_at,
    ea.status
  FROM exam_attempts ea
  WHERE ea.user_id = user_uuid AND ea.exam_id = exam_uuid
  ORDER BY ea.attempt_number DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة للتحقق من صلاحية الطالب لبدء الاختبار
CREATE OR REPLACE FUNCTION can_start_exam(
  user_uuid UUID,
  exam_uuid UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  max_attempts INTEGER;
  current_attempts INTEGER;
  has_enrolled BOOLEAN;
  exam_record RECORD;
BEGIN
  -- التحقق من تسجيل الطالب في الكورس
  SELECT EXISTS(
    SELECT 1 FROM exams e
    JOIN courses c ON e.course_id = c.id
    JOIN course_students cs ON c.id = cs.course_id
    WHERE e.id = exam_uuid 
      AND cs.user_id = user_uuid 
      AND cs.status = 'enrolled'
  ) INTO has_enrolled;
  
  IF NOT has_enrolled THEN
    RETURN FALSE;
  END IF;
  
  -- التحقق من عدد المحاولات
  SELECT e.max_attempts INTO max_attempts
  FROM exams e WHERE e.id = exam_uuid;
  
  SELECT COUNT(*) INTO current_attempts
  FROM exam_attempts 
  WHERE user_id = user_uuid AND exam_id = exam_uuid;
  
  -- التحقق من الوقت
  SELECT * INTO exam_record FROM exams WHERE id = exam_uuid;
  
  RETURN (
    current_attempts < COALESCE(max_attempts, 999) AND
    (exam_record.start_time IS NULL OR exam_record.start_time <= NOW()) AND
    (exam_record.end_time IS NULL OR exam_record.end_time >= NOW())
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة لإنشاء محاولة اختبار جديدة
CREATE OR REPLACE FUNCTION create_exam_attempt(
  user_uuid UUID,
  exam_uuid UUID
)
RETURNS UUID AS $$
DECLARE
  attempt_id UUID;
  next_attempt_number INTEGER;
BEGIN
  -- التحقق من الصلاحية
  IF NOT can_start_exam(user_uuid, exam_uuid) THEN
    RAISE EXCEPTION 'User cannot start this exam';
  END IF;
  
  -- الحصول على رقم المحاولة التالية
  SELECT COALESCE(MAX(attempt_number), 0) + 1 INTO next_attempt_number
  FROM exam_attempts
  WHERE user_id = user_uuid AND exam_id = exam_uuid;
  
  -- إنشاء المحاولة
  INSERT INTO exam_attempts (
    exam_id, 
    user_id, 
    attempt_number, 
    status,
    total_points
  )
  SELECT 
    exam_uuid,
    user_uuid,
    next_attempt_number,
    'in_progress',
    COALESCE(SUM(q.points), 0)
  FROM questions 
  WHERE exam_id = exam_uuid
  RETURNING id INTO attempt_id;
  
  RETURN attempt_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة للحصول على الاشتراك النشط للمستخدم
CREATE OR REPLACE FUNCTION get_user_active_subscription(user_uuid UUID)
RETURNS TABLE (
  subscription_id UUID,
  plan_name TEXT,
  status TEXT,
  start_date DATE,
  end_date DATE,
  days_remaining INTEGER,
  features JSONB
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    us.id as subscription_id,
    sp.name as plan_name,
    us.status,
    us.start_date,
    us.end_date,
    us.end_date - CURRENT_DATE as days_remaining,
    us.features
  FROM user_subscriptions us
  JOIN subscription_plans sp ON us.subscription_plan_id = sp.id
  WHERE us.user_id = user_uuid 
    AND us.status = 'active'
    AND us.end_date >= CURRENT_DATE
  ORDER BY us.end_date DESC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة للتحقق من صلاحية الاشتراك للمستخدم
CREATE OR REPLACE FUNCTION has_valid_subscription(user_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS(
    SELECT 1 FROM user_subscriptions
    WHERE user_id = user_uuid 
      AND status = 'active'
      AND end_date >= CURRENT_DATE
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة لإنشاء طلب جديد
CREATE OR REPLACE FUNCTION create_new_order(
  user_uuid UUID,
  order_type_param TEXT DEFAULT 'subscription',
  items_data JSONB,
  discount_code_param TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  order_uuid UUID;
  total_amount_calc DECIMAL := 0;
  item_record JSONB;
  order_number_val TEXT;
BEGIN
  -- توليد رقم الطلب
  SELECT generate_order_number() INTO order_number_val;
  
  -- حساب المبلغ الإجمالي
  FOR item_record IN SELECT * FROM jsonb_array_elements(items_data)
  LOOP
    total_amount_calc := total_amount_calc + (item_record->>'unit_price')::DECIMAL * (item_record->>'quantity')::INTEGER;
  END LOOP;
  
  -- تطبيق الخصم إذا وجد (Remark: calculate_discounted_price logic missing in functions.sql, assuming simple pass-through or error if not defined. Adding stub if needed.)
  -- IF discount_code_param IS NOT NULL THEN
  --   total_amount_calc := calculate_discounted_price(total_amount_calc, discount_code_param, total_amount_calc);
  -- END IF;
  
  -- إنشاء الطلب
  INSERT INTO orders (
    user_id,
    order_number,
    order_type,
    total_amount,
    discount_code,
    ordered_at
  ) VALUES (
    user_uuid,
    order_number_val,
    order_type_param,
    total_amount_calc,
    discount_code_param,
    NOW()
  ) RETURNING id INTO order_uuid;
  
  -- إضافة عناصر الطلب
  FOR item_record IN SELECT * FROM jsonb_array_elements(items_data)
  LOOP
    INSERT INTO order_items (
      order_id,
      item_type,
      item_id,
      item_name,
      unit_price,
      quantity,
      total_price
    ) VALUES (
      order_uuid,
      item_record->>'item_type',
      (item_record->>'item_id')::UUID,
      item_record->>'item_name',
      (item_record->>'unit_price')::DECIMAL,
      (item_record->>'quantity')::INTEGER,
      (item_record->>'unit_price')::DECIMAL * (item_record->>'quantity')::INTEGER
    );
  END LOOP;
  
  RETURN order_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة لإنشاء اشتراك من طلب مدفوع
CREATE OR REPLACE FUNCTION create_subscription_from_order(order_uuid UUID)
RETURNS BOOLEAN AS $$
DECLARE
  order_rec RECORD;
  plan_rec RECORD;
  subscription_id UUID;
BEGIN
  SELECT * INTO order_rec FROM orders WHERE id = order_uuid;
  
  -- الحصول على خطة الاشتراك من عناصر الطلب
  SELECT sp.* INTO plan_rec
  FROM order_items oi
  JOIN subscription_plans sp ON oi.item_id = sp.id
  WHERE oi.order_id = order_uuid
  LIMIT 1;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No subscription plan found for order';
  END IF;
  
  -- إنشاء الاشتراك
  INSERT INTO user_subscriptions (
    user_id,
    order_id,
    subscription_plan_id,
    status,
    start_date,
    end_date,
    features,
    max_courses,
    max_downloads
  ) VALUES (
    order_rec.user_id,
    order_uuid,
    plan_rec.id,
    'active',
    CURRENT_DATE,
    CURRENT_DATE + (plan_rec.duration_months || ' months')::INTERVAL,
    plan_rec.features,
    plan_rec.max_courses,
    plan_rec.max_downloads
  ) RETURNING id INTO subscription_id;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة لتحديث حالة الطلب بعد الدفع
CREATE OR REPLACE FUNCTION update_order_payment_status(
  order_uuid UUID,
  payment_status_param TEXT,
  transaction_id_param TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  order_record RECORD;
BEGIN
  SELECT * INTO order_record FROM orders WHERE id = order_uuid;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;
  
  -- تحديث الطلب
  UPDATE orders SET
    payment_status = payment_status_param,
    payment_transaction_id = transaction_id_param,
    status = CASE 
      WHEN payment_status_param = 'paid' THEN 'completed'
      WHEN payment_status_param = 'failed' THEN 'cancelled'
      ELSE status
    END,
    paid_at = CASE WHEN payment_status_param = 'paid' THEN NOW() ELSE paid_at END,
    updated_at = NOW()
  WHERE id = order_uuid;
  
  -- إذا تم الدفع بنجاح، إنشاء الاشتراك
  IF payment_status_param = 'paid' AND order_record.order_type = 'subscription' THEN
    PERFORM create_subscription_from_order(order_uuid);
  END IF;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة للحصول على إحصائيات المدرس
CREATE OR REPLACE FUNCTION get_teacher_statistics(teacher_uuid UUID DEFAULT auth.uid())
RETURNS TABLE (
  total_courses BIGINT,
  total_students BIGINT,
  total_revenue DECIMAL,
  active_subscriptions BIGINT,
  monthly_revenue DECIMAL
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (SELECT COUNT(*) FROM courses WHERE instructor_id = teacher_uuid) as total_courses,
    (SELECT COUNT(DISTINCT cs.user_id) 
     FROM course_students cs 
     JOIN courses c ON cs.course_id = c.id 
     WHERE c.instructor_id = teacher_uuid) as total_students,
    (SELECT COALESCE(SUM(o.total_amount), 0) 
     FROM orders o 
     WHERE o.user_id IN (
       SELECT DISTINCT cs.user_id 
       FROM course_students cs 
       JOIN courses c ON cs.course_id = c.id 
       WHERE c.instructor_id = teacher_uuid
     ) AND o.payment_status = 'paid') as total_revenue,
    (SELECT COUNT(*) 
     FROM user_subscriptions us 
     WHERE us.user_id IN (
       SELECT DISTINCT cs.user_id 
       FROM course_students cs 
       JOIN courses c ON cs.course_id = c.id 
       WHERE c.instructor_id = teacher_uuid
     ) AND us.status = 'active') as active_subscriptions,
    (SELECT COALESCE(SUM(o.total_amount), 0) 
     FROM orders o 
     WHERE o.user_id IN (
       SELECT DISTINCT cs.user_id 
       FROM course_students cs 
       JOIN courses c ON cs.course_id = c.id 
       WHERE c.instructor_id = teacher_uuid
     ) AND o.payment_status = 'paid'
       AND o.ordered_at >= DATE_TRUNC('month', NOW())) as monthly_revenue;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- From database_functions_additional.sql

-- دالة للحصول على إحصائيات النظام العامة
CREATE OR REPLACE FUNCTION get_system_statistics()
RETURNS TABLE (
  total_users BIGINT,
  total_teachers BIGINT,
  total_students BIGINT,
  total_courses BIGINT,
  total_lessons BIGINT,
  total_exams BIGINT,
  total_subscriptions BIGINT,
  total_revenue DECIMAL,
  monthly_active_users BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (SELECT COUNT(*) FROM auth.users) as total_users,
    (SELECT COUNT(*) FROM public.users u 
     JOIN public.user_roles ur ON u.id = ur.user_id 
     JOIN public.roles r ON ur.role_id = r.id 
     WHERE r.name = 'teacher') as total_teachers,
    (SELECT COUNT(*) FROM public.users u 
     JOIN public.user_roles ur ON u.id = ur.user_id 
     JOIN public.roles r ON ur.role_id = r.id 
     WHERE r.name = 'student') as total_students,
    (SELECT COUNT(*) FROM courses) as total_courses,
    (SELECT COUNT(*) FROM lessons) as total_lessons,
    (SELECT COUNT(*) FROM exams) as total_exams,
    (SELECT COUNT(*) FROM user_subscriptions WHERE status = 'active') as total_subscriptions,
    (SELECT COALESCE(SUM(total_amount), 0) FROM orders WHERE payment_status = 'paid') as total_revenue,
    (SELECT COUNT(DISTINCT user_id) FROM lesson_progress WHERE updated_at >= CURRENT_DATE - INTERVAL '30 days') as monthly_active_users;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة لإنشاء إشعار جديد
CREATE OR REPLACE FUNCTION create_notification(
  user_uuid UUID,
  title_param TEXT,
  message_param TEXT,
  notification_type_param TEXT DEFAULT 'info',
  data_param JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  notification_uuid UUID;
BEGIN
  INSERT INTO notifications (
    user_id,
    title,
    message,
    type,
    data,
    is_read,
    created_at
  ) VALUES (
    user_uuid,
    title_param,
    message_param,
    notification_type_param,
    data_param,
    false,
    NOW()
  ) RETURNING id INTO notification_uuid;
  
  RETURN notification_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة للحصول على إشعارات المستخدم
CREATE OR REPLACE FUNCTION get_user_notifications(
  user_uuid UUID DEFAULT auth.uid(),
  limit_param INTEGER DEFAULT 50,
  unread_only BOOLEAN DEFAULT false
)
RETURNS TABLE (
  notification_id UUID,
  title TEXT,
  message TEXT,
  type TEXT,
  is_read BOOLEAN,
  created_at TIMESTAMP,
  data JSONB
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    n.id as notification_id,
    n.title,
    n.message,
    n.type,
    n.is_read,
    n.created_at,
    n.data
  FROM notifications n
  WHERE n.user_id = user_uuid
    AND (NOT unread_only OR n.is_read = false)
  ORDER BY n.created_at DESC
  LIMIT limit_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة البحث الشامل
CREATE OR REPLACE FUNCTION global_search(
  search_term TEXT,
  search_type TEXT DEFAULT 'all',
  limit_param INTEGER DEFAULT 20
)
RETURNS TABLE (
  result_type TEXT,
  result_id UUID,
  title TEXT,
  description TEXT,
  relevance_score DECIMAL
) AS $$
BEGIN
  RETURN QUERY
  WITH search_results AS (
    SELECT 
      'course' as result_type,
      c.id as result_id,
      c.title,
      COALESCE(c.description, '') as description,
      ts_rank_cd(
        to_tsvector('arabic', c.title || ' ' || COALESCE(c.description, '')),
        plainto_tsquery('arabic', search_term)
      ) as relevance_score
    FROM courses c
    WHERE (search_type = 'all' OR search_type = 'courses')
      AND (
        to_tsvector('arabic', c.title || ' ' || COALESCE(c.description, '')) 
        @@ plainto_tsquery('arabic', search_term)
        OR c.title ILIKE '%' || search_term || '%'
      )
      AND c.status = 'published'
  )
  SELECT 
    sr.result_type,
    sr.result_id,
    sr.title,
    sr.description,
    sr.relevance_score
  FROM search_results sr
  ORDER BY sr.relevance_score DESC
  LIMIT limit_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة لتنظيف البيانات المؤقتة
CREATE OR REPLACE FUNCTION cleanup_temp_data()
RETURNS TABLE (
  table_name TEXT,
  deleted_rows BIGINT
) AS $$
DECLARE
  deleted_count BIGINT;
BEGIN
  -- Removing queries to tables not defined in this schema (user_sessions, verification_tokens) to avoid errors
  -- DELETE FROM user_sessions WHERE expires_at < NOW();
  -- GET DIAGNOSTICS deleted_count = ROW_COUNT;
  -- RETURN QUERY SELECT 'user_sessions'::TEXT, deleted_count;
  
  RETURN QUERY SELECT 'none'::TEXT, 0::BIGINT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة للتحقق من صلاحية كلمة المرور
CREATE OR REPLACE FUNCTION validate_password_strength(password_text TEXT)
RETURNS TABLE (
  is_valid BOOLEAN,
  errors TEXT[]
) AS $$
DECLARE
  errors_list TEXT[] := ARRAY[]::TEXT[];
  has_upper BOOLEAN;
  has_lower BOOLEAN;
  has_digit BOOLEAN;
BEGIN
  IF length(password_text) < 8 THEN
    errors_list := array_append(errors_list, 'كلمة المرور يجب أن تكون 8 أحرف على الأقل');
  END IF;
  
  has_upper := password_text ~ '[A-Z]';
  IF NOT has_upper THEN
    errors_list := array_append(errors_list, 'كلمة المرور يجب أن تحتوي على حرف كبير واحد على الأقل');
  END IF;
  
  has_lower := password_text ~ '[a-z]';
  IF NOT has_lower THEN
    errors_list := array_append(errors_list, 'كلمة المرور يجب أن تحتوي على حرف صغير واحد على الأقل');
  END IF;
  
  has_digit := password_text ~ '[0-9]';
  IF NOT has_digit THEN
    errors_list := array_append(errors_list, 'كلمة المرور يجب أن تحتوي على رقم واحد على الأقل');
  END IF;
  
  RETURN QUERY SELECT 
    array_length(errors_list, 1) IS NULL as is_valid,
    errors_list;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة للحصول على إحصائيات الأداء
CREATE OR REPLACE FUNCTION get_performance_stats()
RETURNS TABLE (
  metric_name TEXT,
  metric_value NUMERIC,
  unit TEXT,
  recorded_at TIMESTAMP
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    'database_size_mb' as metric_name,
    pg_database_size(current_database()) / 1024 / 1024 as metric_value,
    'MB' as unit,
    NOW() as recorded_at
  
  UNION ALL
  
  SELECT 
    'active_connections' as metric_name,
    COUNT(*) as metric_value,
    'connections' as unit,
    NOW() as recorded_at
  FROM pg_stat_activity
  
  UNION ALL
  
  SELECT 
    'index_hit_ratio' as metric_name,
    CASE 
      WHEN SUM(idx_tup_read) > 0 
      THEN ROUND((SUM(idx_tup_fetch)::DECIMAL / SUM(idx_tup_read)::DECIMAL) * 100, 2)
      ELSE 100 
    END as metric_value,
    'percentage' as unit,
    NOW() as recorded_at
  FROM pg_stat_user_indexes;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة لتحليل سلوك المستخدمين
CREATE OR REPLACE FUNCTION analyze_user_behavior(
  user_uuid UUID,
  days_back INTEGER DEFAULT 30
)
RETURNS TABLE (
  metric_name TEXT,
  metric_value NUMERIC,
  period TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    'lessons_completed' as metric_name,
    COUNT(*)::NUMERIC as metric_value,
    'last_' || days_back || '_days' as period
  FROM lesson_progress
  WHERE user_id = user_uuid 
    AND is_completed = true
    AND updated_at >= CURRENT_DATE - (days_back || ' days')::INTERVAL
  
  UNION ALL
  
  SELECT 
    'exams_taken' as metric_name,
    COUNT(*)::NUMERIC as metric_value,
    'last_' || days_back || '_days' as period
  FROM exam_attempts
  WHERE user_id = user_uuid 
    AND submitted_at >= CURRENT_DATE - (days_back || ' days')::INTERVAL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة للحصول على التوصيات الذكية
CREATE OR REPLACE FUNCTION get_personalized_recommendations(
  user_uuid UUID,
  limit_param INTEGER DEFAULT 10
)
RETURNS TABLE (
  course_id UUID,
  course_title TEXT,
  course_description TEXT,
  instructor_name TEXT,
  match_score DECIMAL,
  reasons JSONB
) AS $$
BEGIN
  RETURN QUERY
  WITH user_interests AS (
    SELECT DISTINCT c.category_id
    FROM courses c
    JOIN lessons l ON c.id = l.course_id
    JOIN lesson_progress lp ON l.id = lp.lesson_id
    WHERE lp.user_id = user_uuid 
      AND lp.is_completed = true
  )
  SELECT 
    c.id as course_id,
    c.title as course_title,
    COALESCE(c.description, '') as course_description,
    u.full_name as instructor_name,
    CASE 
      WHEN c.category_id IN (SELECT category_id FROM user_interests) THEN 0.8
      ELSE 0.3
    END as match_score,
    jsonb_build_array('يتطابق مع اهتماماتك') as reasons
  FROM courses c
  JOIN public.users u ON c.instructor_id = u.id
  WHERE c.status = 'published'
    AND c.id NOT IN (
      SELECT course_id FROM course_students 
      WHERE user_id = user_uuid AND status = 'enrolled'
    )
  ORDER BY match_score DESC
  LIMIT limit_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة لتصدير بيانات المستخدم
CREATE OR REPLACE FUNCTION export_user_data(
  user_uuid UUID DEFAULT auth.uid()
)
RETURNS JSONB AS $$
DECLARE
  user_data JSONB;
BEGIN
  SELECT jsonb_build_object(
    'user_profile', (
      SELECT jsonb_build_object(
        'id', u.id,
        'full_name', u.full_name,
        'email', u.email,
        'created_at', u.created_at
      )
      FROM public.users u WHERE u.id = user_uuid
    ),
    'enrolled_courses', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'course_id', cs.course_id,
          'course_title', c.title,
          'enrolled_at', cs.enrolled_at,
          'status', cs.status
        )
      )
      FROM course_students cs
      JOIN courses c ON cs.course_id = c.id
      WHERE cs.user_id = user_uuid
    ),
    'lesson_progress', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'lesson_id', lp.lesson_id,
          'lesson_title', l.title,
          'progress', lp.progress,
          'is_completed', lp.is_completed,
          'updated_at', lp.updated_at
        )
      )
      FROM lesson_progress lp
      JOIN lessons l ON lp.lesson_id = l.id
      WHERE lp.user_id = user_uuid
    )
  ) INTO user_data;
  
  RETURN user_data;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 6. ROW LEVEL SECURITY (RLS) POLICIES (COMPLETE)
-- ============================================
-- Enabling RLS on standard tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_students ENABLE ROW LEVEL SECURITY;

-- Basic Policies from Schema
CREATE POLICY "Public profiles are viewable by everyone" ON public.users FOR SELECT USING (true);
CREATE POLICY "Users can insert their own profile" ON public.users FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.users FOR UPDATE USING (auth.uid() = id);

-- Additional Policies from users_policies.sql
CREATE POLICY "Enable read access for authenticated users" ON public.users FOR SELECT USING (auth.role() = 'authenticated');
-- Note: 'Enable update...' logic for admin is covered if is_admin() works correctly.
-- We add 'Admins can delete users'
CREATE POLICY "Admins can delete users" ON public.users FOR DELETE USING ( is_admin() );

-- Course Policies
CREATE POLICY "Courses viewable by everyone" ON public.courses FOR SELECT USING (is_published = true OR is_admin() OR is_teacher());
CREATE POLICY "Lessons viewable by enrolled or admin" ON public.lessons FOR SELECT USING (
    EXISTS (SELECT 1 FROM enrollments WHERE user_id = auth.uid() AND course_id = lessons.course_id AND status = 'active')
    OR
    EXISTS (SELECT 1 FROM course_students WHERE user_id = auth.uid() AND course_id = lessons.course_id)
    OR
    is_admin() OR is_teacher() OR is_free = true
);

-- ============================================
-- END OF SCHEMA
-- ============================================
