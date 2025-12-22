-- ============================================
-- جداول نظام الاختبارات
-- ============================================

-- 1. جدول الاختبارات (Exams)
CREATE TABLE public.exams (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  course_id UUID NOT NULL,
  title TEXT NOT NULL,
  description TEXT NULL,
  duration INTEGER NOT NULL, -- المدة بالدقائق
  total_points INTEGER NOT NULL DEFAULT 100,
  passing_score INTEGER NOT NULL DEFAULT 60, -- الدرجة المطلوبة للنجاح
  is_published BOOLEAN NOT NULL DEFAULT false,
  start_time TIMESTAMP NULL, -- وقت بدء الاختبار (اختياري)
  end_time TIMESTAMP NULL, -- وقت انتهاء الاختبار (اختياري)
  max_attempts INTEGER NULL DEFAULT 3, -- عدد المحاولات المسموحة
  show_results_immediately BOOLEAN NOT NULL DEFAULT true, -- عرض النتائج فوراً
  shuffle_questions BOOLEAN NOT NULL DEFAULT false, -- خلط ترتيب الأسئلة
  shuffle_options BOOLEAN NOT NULL DEFAULT false, -- خلط ترتيب الخيارات
  created_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  
  CONSTRAINT exams_pkey PRIMARY KEY (id),
  CONSTRAINT exams_course_id_fkey FOREIGN KEY (course_id) 
    REFERENCES courses(id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- 2. جدول الأسئلة (Questions)
CREATE TABLE public.questions (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  exam_id UUID NOT NULL,
  question_text TEXT NOT NULL,
  question_type TEXT NOT NULL DEFAULT 'multiple_choice', -- multiple_choice, true_false, essay
  options JSONB NULL, -- خيارات الإجابة للأسئلة متعددة الخيارات
  correct_answer JSONB NOT NULL, -- الإجابة الصحيحة
  explanation TEXT NULL, -- شرح الإجابة
  points INTEGER NOT NULL DEFAULT 1,
  order_index INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  
  CONSTRAINT questions_pkey PRIMARY KEY (id),
  CONSTRAINT questions_exam_id_fkey FOREIGN KEY (exam_id) 
    REFERENCES exams(id) ON DELETE CASCADE,
  CONSTRAINT questions_type_check CHECK (
    question_type = ANY (ARRAY[
      'multiple_choice'::TEXT,
      'true_false'::TEXT,
      'essay'::TEXT
    ])
  )
) TABLESPACE pg_default;

-- 3. جدول محاولات الاختبارات (Exam Attempts)
CREATE TABLE public.exam_attempts (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  exam_id UUID NOT NULL,
  user_id UUID NOT NULL,
  started_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
  submitted_at TIMESTAMP WITHOUT TIME ZONE NULL,
  score INTEGER NULL, -- الدرجة المحصلة
  total_points INTEGER NOT NULL, -- إجمالي النقاط
  percentage DECIMAL(5,2) NULL, -- النسبة المئوية
  is_passed BOOLEAN NULL, -- هل نجح الطالب
  time_taken INTEGER NULL, -- الوقت المستغرق بالثواني
  attempt_number INTEGER NOT NULL DEFAULT 1,
  status TEXT NOT NULL DEFAULT 'in_progress', -- in_progress, submitted, graded
  
  CONSTRAINT exam_attempts_pkey PRIMARY KEY (id),
  CONSTRAINT exam_attempts_exam_id_fkey FOREIGN KEY (exam_id) 
    REFERENCES exams(id) ON DELETE CASCADE,
  CONSTRAINT exam_attempts_user_id_fkey FOREIGN KEY (user_id) 
    REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT exam_attempts_status_check CHECK (
    status = ANY (ARRAY[
      'in_progress'::TEXT,
      'submitted'::TEXT,
      'graded'::TEXT
    ])
  )
) TABLESPACE pg_default;

-- 4. جدول إجابات الطلاب (Exam Answers)
CREATE TABLE public.exam_answers (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  attempt_id UUID NOT NULL,
  question_id UUID NOT NULL,
  user_answer JSONB NULL, -- إجابة الطالب
  is_correct BOOLEAN NULL, -- هل الإجابة صحيحة
  points_earned INTEGER NULL DEFAULT 0, -- النقاط المكتسبة
  answered_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  
  CONSTRAINT exam_answers_pkey PRIMARY KEY (id),
  CONSTRAINT exam_answers_attempt_id_fkey FOREIGN KEY (attempt_id) 
    REFERENCES exam_attempts(id) ON DELETE CASCADE,
  CONSTRAINT exam_answers_question_id_fkey FOREIGN KEY (question_id) 
    REFERENCES questions(id) ON DELETE CASCADE,
  CONSTRAINT exam_answers_unique UNIQUE (attempt_id, question_id)
) TABLESPACE pg_default;

-- ============================================
-- الفهارس (Indexes) لتحسين الأداء
-- ============================================

CREATE INDEX idx_exams_course_id ON public.exams(course_id);
CREATE INDEX idx_exams_published ON public.exams(is_published);
CREATE INDEX idx_questions_exam_id ON public.questions(exam_id);
CREATE INDEX idx_exam_attempts_exam_id ON public.exam_attempts(exam_id);
CREATE INDEX idx_exam_attempts_user_id ON public.exam_attempts(user_id);
CREATE INDEX idx_exam_attempts_status ON public.exam_attempts(status);
CREATE INDEX idx_exam_answers_attempt_id ON public.exam_answers(attempt_id);
CREATE INDEX idx_exam_answers_question_id ON public.exam_answers(question_id);

-- ============================================
-- Row Level Security (RLS) Policies
-- ============================================

-- تفعيل RLS على الجداول
ALTER TABLE public.exams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_answers ENABLE ROW LEVEL SECURITY;

-- سياسات الاختبارات: يمكن للجميع القراءة، المدرسون فقط يمكنهم الكتابة
CREATE POLICY "الجميع يمكنهم قراءة الاختبارات المنشورة"
  ON public.exams FOR SELECT
  USING (is_published = true);

CREATE POLICY "المدرسون يمكنهم إدارة الاختبارات"
  ON public.exams FOR ALL
  USING (auth.uid() IN (
    SELECT instructor_id FROM courses WHERE id = course_id
  ));

-- سياسات الأسئلة: مرتبطة بسياسات الاختبارات
CREATE POLICY "الجميع يمكنهم قراءة الأسئلة للاختبارات المنشورة"
  ON public.questions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM exams 
      WHERE exams.id = exam_id AND exams.is_published = true
    )
  );

CREATE POLICY "المدرسون يمكنهم إدارة الأسئلة"
  ON public.questions FOR ALL
  USING (
    auth.uid() IN (
      SELECT c.instructor_id 
      FROM exams e 
      JOIN courses c ON e.course_id = c.id 
      WHERE e.id = exam_id
    )
  );

-- سياسات محاولات الاختبارات: المستخدم يمكنه رؤية محاولاته فقط
CREATE POLICY "المستخدمون يمكنهم رؤية محاولاتهم فقط"
  ON public.exam_attempts FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "المستخدمون يمكنهم إنشاء محاولات جديدة"
  ON public.exam_attempts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "المستخدمون يمكنهم تحديث محاولاتهم"
  ON public.exam_attempts FOR UPDATE
  USING (auth.uid() = user_id);

-- سياسات إجابات الطلاب
CREATE POLICY "المستخدمون يمكنهم رؤية إجاباتهم فقط"
  ON public.exam_answers FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM exam_attempts 
      WHERE exam_attempts.id = attempt_id 
      AND exam_attempts.user_id = auth.uid()
    )
  );

CREATE POLICY "المستخدمون يمكنهم إضافة إجاباتهم"
  ON public.exam_answers FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM exam_attempts 
      WHERE exam_attempts.id = attempt_id 
      AND exam_attempts.user_id = auth.uid()
    )
  );

CREATE POLICY "المستخدمون يمكنهم تحديث إجاباتهم"
  ON public.exam_answers FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM exam_attempts 
      WHERE exam_attempts.id = attempt_id 
      AND exam_attempts.user_id = auth.uid()
    )
  );

-- ============================================
-- دوال مساعدة (Helper Functions)
-- ============================================

-- دالة لحساب نتيجة الاختبار تلقائياً
CREATE OR REPLACE FUNCTION calculate_exam_score(attempt_id_param UUID)
RETURNS VOID AS $$
DECLARE
  total_score INTEGER;
  total_possible INTEGER;
  pass_score INTEGER;
  calc_percentage DECIMAL(5,2);
  is_pass BOOLEAN;
BEGIN
  -- حساب مجموع النقاط المكتسبة
  SELECT COALESCE(SUM(points_earned), 0)
  INTO total_score
  FROM exam_answers
  WHERE attempt_id = attempt_id_param;
  
  -- الحصول على إجمالي النقاط ودرجة النجاح
  SELECT ea.total_points, e.passing_score
  INTO total_possible, pass_score
  FROM exam_attempts ea
  JOIN exams e ON ea.exam_id = e.id
  WHERE ea.id = attempt_id_param;
  
  -- حساب النسبة المئوية
  IF total_possible > 0 THEN
    calc_percentage := (total_score::DECIMAL / total_possible::DECIMAL) * 100;
  ELSE
    calc_percentage := 0;
  END IF;
  
  -- تحديد النجاح أو الرسوب
  is_pass := calc_percentage >= pass_score;
  
  -- تحديث محاولة الاختبار
  UPDATE exam_attempts
  SET 
    score = total_score,
    percentage = calc_percentage,
    is_passed = is_pass,
    status = 'graded',
    submitted_at = NOW()
  WHERE id = attempt_id_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- بيانات تجريبية (Optional - للاختبار)
-- ============================================

-- يمكنك إضافة بيانات تجريبية هنا إذا أردت
-- مثال:
/*
INSERT INTO exams (course_id, title, description, duration, total_points)
VALUES (
  'YOUR_COURSE_ID',
  'اختبار تجريبي',
  'هذا اختبار تجريبي للتأكد من عمل النظام',
  30,
  50
);
*/
