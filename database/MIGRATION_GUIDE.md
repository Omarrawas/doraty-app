# Database Migration Instructions

## ⚠️ CRITICAL: Run This in Supabase SQL Editor

You MUST execute the migration script before the app features will work properly.

## Steps:

### 1. **Open Supabase Dashboard**
   - Navigate to your project
   - Go to **SQL Editor** tab

### 2. **Execute Migration**
   - Copy the entire contents of `database/migrations/add_dynamic_progress_featured.sql`
   - Paste into a new query in Supabase SQL Editor
   - Click **Run** (or press Ctrl+Enter)

### 3. **Verify Success**
   You should see success messages for:
   - ✅ 4 new columns added to `enrollments`
   - ✅ 3 new columns added to `courses` 
   - ✅ 2 functions created
   - ✅ 1 trigger created
   - ✅ Existing data backfilled
   - ✅ 2 views created

### 4. **Check Results**
   Run this query to verify:
   ```sql
   -- Check enrollments table
   SELECT column_name, data_type 
   FROM information_schema.columns 
   WHERE table_name = 'enrollments'
   AND column_name IN ('completed_lessons', 'total_lessons', 'progress_percentage', 'last_accessed_lesson_id');

   -- Check courses table
   SELECT column_name, data_type 
   FROM information_schema.columns 
   WHERE table_name = 'courses'
   AND column_name IN ('students_count', 'is_featured', 'featured_order');

   -- View current featured courses
   SELECT title, students_count, is_featured, featured_order
   FROM courses
   WHERE is_featured = TRUE
   ORDER BY featured_order;
   ```

## What Gets Created:

### New Columns in `enrollments`:
- `completed_lessons` - Tracks how many lessons the student finished
- `total_lessons` - Total lessons in the course
- `progress_percentage` - Auto-calculated (0.00 to 100.00)
- `last_accessed_lesson_id` - Reference to resume from last position

### New Columns in `courses`:
- `students_count` - Auto-updated count (triggers on enrollment insert/delete)
- `is_featured` - Admin flag for banner carousel
- `featured_order` - Display sequence (1, 2, 3...)

### Database Functions:
1. `update_course_student_count()` - Auto-maintains student counts
2. `update_enrollment_progress(enrollment_id, course_id)` - Recalculates progress

### Triggers:
- `enrollments_count_trigger` - Fires on every enrollment insert/delete

### Views (Optional Helpers):
- `enrollment_progress_summary` - Join view for easy querying
- `featured_courses_view` - Quick access to featured courses

## Managing Featured Courses

### To Mark a Course as Featured:
```sql
UPDATE courses
SET is_featured = TRUE, featured_order = 1
WHERE title = 'دورة الفيزياء المتقدمة';
```

### To Reorder Featured Courses:
```sql
-- Swap positions of two courses
UPDATE courses SET featured_order = 1 WHERE id = 'course-id-1';
UPDATE courses SET featured_order = 2 WHERE id = 'course-id-2';
```

### To Remove from Featured:
```sql
UPDATE courses
SET is_featured = FALSE
WHERE id = 'course-id-to-remove';
```

## Troubleshooting

### "Relation does not exist" error:
- Ensure you're running in the correct database schema (usually `public`)

### "Column already exists" error:
- Migration was already run. Check existing columns with:
  ```sql
  SELECT * FROM information_schema.columns WHERE table_name = 'enrollments';
  ```

### Progress Not Updating:
- Call the update function manually:
  ```sql
  SELECT update_enrollment_progress('enrollment-id', 'course-id');
  ```

## Rollback (If Needed)

### To Remove All Changes:
```sql
-- Drop views
DROP VIEW IF EXISTS enrollment_progress_summary;
DROP VIEW IF EXISTS featured_courses_view;

-- Drop trigger and function
DROP TRIGGER IF EXISTS enrollments_count_trigger ON enrollments;
DROP FUNCTION IF EXISTS update_course_student_count();
DROP FUNCTION IF EXISTS update_enrollment_progress(UUID, UUID);

-- Remove columns from enrollments
ALTER TABLE enrollments 
DROP COLUMN IF EXISTS completed_lessons,
DROP COLUMN IF EXISTS total_lessons,
DROP COLUMN IF EXISTS progress_percentage,
DROP COLUMN IF EXISTS last_accessed_lesson_id;

-- Remove columns from courses
ALTER TABLE courses 
DROP COLUMN IF EXISTS students_count,
DROP COLUMN IF EXISTS is_featured,
DROP COLUMN IF EXISTS featured_order;
```

## Next Steps After Migration

1. **Restart your app** to ensure Supabase client picks up schema changes
2. **Test Continue Learning** - Progress should now be dynamic
3. **Mark courses as featured** using SQL queries above
4. **Enroll in a course** to see student count auto-increment
5. **(Optional)** Build admin panel to manage featured courses via UI
