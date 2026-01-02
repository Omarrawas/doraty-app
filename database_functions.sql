-- ============================================
-- ملف الدوال والوظائف الشامل (Functions)
-- ============================================

-- ============================================
-- دوال إدارة المستخدمين والأدوار
-- ============================================

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
  VALUES (user_uuid, full_name, email, NOW(), NOW());
  
  -- إضافة الدور
  INSERT INTO public.user_roles (user_id, role_id, created_at)
  VALUES (user_uuid, role_id, NOW());
  
  RETURN TRUE;
EXCEPTION
  WHEN unique_violation THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- دوال إدارة الكورسات والدروس
-- ============================================

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

-- ============================================
-- دوال إدارة الاختبارات
-- ============================================

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

-- ============================================
-- دوال إدارة الطلبات والاشتراكات
-- ============================================

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
  
  -- تطبيق الخصم إذا وجد
  IF discount_code_param IS NOT NULL THEN
    total_amount_calc := calculate_discounted_price(total_amount_calc, discount_code_param, total_amount_calc);
  END IF;
  
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

-- ============================================
-- دوال إدارة الإحصائيات والتقارير
-- ============================================

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
END
