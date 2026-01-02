-- ============================================
-- ملف الدوال الإضافية والوظائف المتقدمة
-- ============================================

-- ============================================
-- دوال إدارة الإحصائيات والتقارير
-- ============================================

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

-- ============================================
-- دوال الإشعارات
-- ============================================

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

-- ============================================
-- دوال البحث
-- ============================================

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

-- ============================================
-- دوال الأمان والصيانة
-- ============================================

-- دالة لتنظيف البيانات المؤقتة
CREATE OR REPLACE FUNCTION cleanup_temp_data()
RETURNS TABLE (
  table_name TEXT,
  deleted_rows BIGINT
) AS $$
DECLARE
  deleted_count BIGINT;
BEGIN
  DELETE FROM user_sessions WHERE expires_at < NOW();
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  
  RETURN QUERY SELECT 'user_sessions'::TEXT, deleted_count;
  
  DELETE FROM verification_tokens WHERE expires_at < NOW();
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  
  RETURN QUERY SELECT 'verification_tokens'::TEXT, deleted_count;
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

-- ============================================
-- دوال المراقبة والأداء
-- ============================================

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

-- ============================================
-- دوال التحليل المتقدم
-- ============================================

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

-- ============================================
-- دوال التصدير والاستيراد
-- ============================================

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
-- نهاية ملف الدوال الإضافية
-- ============================================

-- أمثلة على استخدام الدوال:
/*
-- إنشاء مستخدم جديد مع دور مدرس
SELECT create_user_with_role(
  '550e8400-e29b-41d4-a716-446655440000'::UUID,
  'أحمد محمد',
  'ahmed@example.com',
  'teacher'
);

-- التحقق من صلاحية المستخدم
SELECT is_admin();

-- الحصول على إحصائيات المدرس
SELECT * FROM get_teacher_statistics();

-- البحث في المحتوى
SELECT * FROM global_search('رياضيات', 'courses', 10);

-- إنشاء إشعار
SELECT create_notification(
  '550e8400-e29b-41d4-a716-446655440000'::UUID,
  'مرحباً بك',
  'تم تسجيلك بنجاح في المنصة',
  'welcome'
);

-- تحليل سلوك المستخدم
SELECT * FROM analyze_user_behavior('550e8400-e29b-41d4-a716-446655440000'::UUID, 30);

-- الحصول على توصيات شخصية
SELECT * FROM get_personalized_recommendations('550e8400-e29b-41d4-a716-446655440000'::UUID, 5);

-- تصدير بيانات المستخدم
SELECT export_user_data('550e8400-e29b-41d4-a716-446655440000'::UUID);
*/
