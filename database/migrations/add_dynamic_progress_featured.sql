-- Migration: Add Dynamic Progress and Featured Content Fields
-- Date: 2026-01-15
-- Description: Adds columns for tracking enrollment progress, course popularity, and featured courses

-- ============================================
-- 1. Add columns to enrollments table
-- ============================================
ALTER TABLE enrollments 
ADD COLUMN IF NOT EXISTS completed_lessons INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_lessons INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS progress_percentage DECIMAL(5,2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS last_accessed_lesson_id UUID REFERENCES lessons(id);

-- Add comments for documentation
COMMENT ON COLUMN enrollments.completed_lessons IS 'Number of lessons completed by the student';
COMMENT ON COLUMN enrollments.total_lessons IS 'Total number of lessons in the course';
COMMENT ON COLUMN enrollments.progress_percentage IS 'Calculated progress percentage (0.00 to 100.00)';
COMMENT ON COLUMN enrollments.last_accessed_lesson_id IS 'Reference to the last lesson the student accessed';

-- ============================================
-- 2. Add columns to courses table
-- ============================================
ALTER TABLE courses 
ADD COLUMN IF NOT EXISTS students_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS featured_order INT DEFAULT 0;

-- Add comments for documentation
COMMENT ON COLUMN courses.students_count IS 'Total number of enrolled students (auto-updated via trigger)';
COMMENT ON COLUMN courses.is_featured IS 'Flag to mark course for display in featured banner/carousel';
COMMENT ON COLUMN courses.featured_order IS 'Display order in featured carousel (1 = first, 2 = second, etc.)';

-- ============================================
-- 3. Create function to auto-update student count
-- ============================================
CREATE OR REPLACE FUNCTION update_course_student_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Increment student count when new enrollment is created
    UPDATE courses 
    SET students_count = students_count + 1 
    WHERE id = NEW.course_id;
  ELSIF TG_OP = 'DELETE' THEN
    -- Decrement student count when enrollment is deleted (never go below 0)
    UPDATE courses 
    SET students_count = GREATEST(students_count - 1, 0) 
    WHERE id = OLD.course_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on enrollments table
DROP TRIGGER IF EXISTS enrollments_count_trigger ON enrollments;
CREATE TRIGGER enrollments_count_trigger
AFTER INSERT OR DELETE ON enrollments
FOR EACH ROW EXECUTE FUNCTION update_course_student_count();

-- ============================================
-- 4. Create function to update enrollment progress
-- ============================================
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
  -- Get user_id from enrollment
  SELECT user_id INTO v_user_id
  FROM enrollments
  WHERE id = p_enrollment_id;

  -- Get total lessons in course
  SELECT COUNT(*) INTO v_total_lessons
  FROM lessons
  WHERE course_id = p_course_id;
  
  -- Get completed lessons for this user in this course
  SELECT COUNT(DISTINCT lp.lesson_id) INTO v_completed_lessons
  FROM lesson_progress lp
  JOIN lessons l ON lp.lesson_id = l.id
  WHERE lp.user_id = v_user_id 
    AND l.course_id = p_course_id 
    AND lp.is_completed = TRUE;
  
  -- Update enrollment with calculated values
  UPDATE enrollments
  SET 
    total_lessons = v_total_lessons,
    completed_lessons = v_completed_lessons,
    progress_percentage = CASE 
      WHEN v_total_lessons > 0 THEN ROUND((v_completed_lessons::DECIMAL / v_total_lessons) * 100, 2)
      ELSE 0
    END
  WHERE id = p_enrollment_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_enrollment_progress IS 'Calculates and updates progress metrics for a specific enrollment';

-- ============================================
-- 5. Backfill existing data
-- ============================================

-- Set initial student counts for all courses
UPDATE courses c
SET students_count = (
  SELECT COUNT(*) 
  FROM enrollments 
  WHERE course_id = c.id
);

-- Mark top 3 highest-rated courses as featured
WITH top_courses AS (
  SELECT id, ROW_NUMBER() OVER (ORDER BY rating DESC, created_at DESC) as row_number
  FROM courses
  WHERE rating >= 4.0
  ORDER BY rating DESC, created_at DESC
  LIMIT 3
)
UPDATE courses
SET 
  is_featured = TRUE, 
  featured_order = top_courses.row_number
FROM top_courses
WHERE courses.id = top_courses.id;

-- Initialize progress for all existing enrollments
DO $$
DECLARE
  enrollment_record RECORD;
BEGIN
  FOR enrollment_record IN 
    SELECT id, course_id FROM enrollments
  LOOP
    PERFORM update_enrollment_progress(enrollment_record.id, enrollment_record.course_id);
  END LOOP;
END $$;

-- ============================================
-- 6. Create helpful views (optional)
-- ============================================

-- View for enrollment progress summary
CREATE OR REPLACE VIEW enrollment_progress_summary AS
SELECT 
  e.id as enrollment_id,
  e.user_id,
  e.course_id,
  c.title as course_title,
  e.completed_lessons,
  e.total_lessons,
  e.progress_percentage,
  e.last_accessed_lesson_id,
  l.title as last_lesson_title,
  e.enrolled_at,
  e.updated_at
FROM enrollments e
JOIN courses c ON e.course_id = c.id
LEFT JOIN lessons l ON e.last_accessed_lesson_id = l.id;

COMMENT ON VIEW enrollment_progress_summary IS 'Convenient view for displaying enrollment progress with course and lesson details';

-- View for featured courses
CREATE OR REPLACE VIEW featured_courses_view AS
SELECT *
FROM courses
WHERE is_featured = TRUE
ORDER BY featured_order ASC;

COMMENT ON VIEW featured_courses_view IS 'Quick access to courses marked for featured banner/carousel';
