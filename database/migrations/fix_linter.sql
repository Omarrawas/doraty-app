-- Fix auth_rls_initplan and multiple_permissive_policies

-- app_settings
DROP POLICY IF EXISTS "Only admins can insert app settings" ON public.app_settings;
CREATE POLICY "Only admins can insert app settings" ON public.app_settings FOR INSERT TO public WITH CHECK (EXISTS ( SELECT 1 FROM user_roles ur JOIN roles r ON ur.role_id = r.id WHERE ur.user_id = (select auth.uid()) AND r.name = 'admin' ));

-- admin_notifications
DROP POLICY IF EXISTS "Admins can insert notifications" ON public.admin_notifications;
CREATE POLICY "Admins can insert notifications" ON public.admin_notifications FOR INSERT TO authenticated WITH CHECK (EXISTS ( SELECT 1 FROM user_roles ur JOIN roles r ON ur.role_id = r.id WHERE ur.user_id = (select auth.uid()) AND r.name = ANY (ARRAY['admin', 'super_admin', 'teacher'])));

DROP POLICY IF EXISTS "Admins can view notifications" ON public.admin_notifications;
CREATE POLICY "Admins can view notifications" ON public.admin_notifications FOR SELECT TO authenticated USING (EXISTS ( SELECT 1 FROM user_roles ur JOIN roles r ON ur.role_id = r.id WHERE ur.user_id = (select auth.uid()) AND r.name = ANY(ARRAY['admin', 'super_admin', 'teacher'])));

-- courses
DROP POLICY IF EXISTS "Admins can delete courses" ON public.courses;
DROP POLICY IF EXISTS "Admins can insert courses" ON public.courses;
DROP POLICY IF EXISTS "Admins can update courses" ON public.courses;
DROP POLICY IF EXISTS "Teachers can manage own courses" ON public.courses;

CREATE POLICY "Teachers can manage own courses_insert" ON public.courses FOR INSERT TO public WITH CHECK (instructor_id = (select auth.uid()) OR get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']));
CREATE POLICY "Teachers can manage own courses_update" ON public.courses FOR UPDATE TO public USING (instructor_id = (select auth.uid()) OR get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']));
CREATE POLICY "Teachers can manage own courses_delete" ON public.courses FOR DELETE TO public USING (instructor_id = (select auth.uid()) OR get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']));

-- enrollments
DROP POLICY IF EXISTS "Admins full access to enrollments" ON public.enrollments;
DROP POLICY IF EXISTS "Manage enrollments" ON public.enrollments;
DROP POLICY IF EXISTS "Teachers can view enrollments for their courses" ON public.enrollments;

CREATE POLICY "Manage enrollments_insert" ON public.enrollments FOR INSERT TO public WITH CHECK (user_id = (select auth.uid()) OR get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']));
CREATE POLICY "Manage enrollments_update" ON public.enrollments FOR UPDATE TO public USING (user_id = (select auth.uid()) OR get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']));
CREATE POLICY "Manage enrollments_delete" ON public.enrollments FOR DELETE TO public USING (user_id = (select auth.uid()) OR get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']));
CREATE POLICY "Manage enrollments_select" ON public.enrollments FOR SELECT TO public USING (user_id = (select auth.uid()) OR get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']) OR EXISTS(SELECT 1 FROM courses c left join teacher_courses tc on tc.course_id = c.id WHERE c.id = enrollments.course_id AND (c.instructor_id = (select auth.uid()) OR tc.teacher_id = (select auth.uid()))));

-- exams
DROP POLICY IF EXISTS "Teachers manage own course exams" ON public.exams;
DROP POLICY IF EXISTS "Teachers can manage exams" ON public.exams;
DROP POLICY IF EXISTS "Teachers can delete own course exams" ON public.exams;
DROP POLICY IF EXISTS "Teachers can write own course exams" ON public.exams;
DROP POLICY IF EXISTS "Teachers can update own course exams" ON public.exams;

CREATE POLICY "Teachers can manage exams_insert" ON public.exams FOR INSERT TO public WITH CHECK (get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']) OR EXISTS(SELECT 1 FROM courses c WHERE c.id = course_id AND c.instructor_id = (select auth.uid())) OR EXISTS(SELECT 1 FROM teacher_courses tc WHERE tc.course_id = course_id AND tc.teacher_id = (select auth.uid())));
CREATE POLICY "Teachers can manage exams_update" ON public.exams FOR UPDATE TO public USING (get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']) OR EXISTS(SELECT 1 FROM courses c WHERE c.id = course_id AND c.instructor_id = (select auth.uid())) OR EXISTS(SELECT 1 FROM teacher_courses tc WHERE tc.course_id = course_id AND tc.teacher_id = (select auth.uid())));
CREATE POLICY "Teachers can manage exams_delete" ON public.exams FOR DELETE TO public USING (get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']) OR EXISTS(SELECT 1 FROM courses c WHERE c.id = course_id AND c.instructor_id = (select auth.uid())) OR EXISTS(SELECT 1 FROM teacher_courses tc WHERE tc.course_id = course_id AND tc.teacher_id = (select auth.uid())));

-- lessons
DROP POLICY IF EXISTS "Teachers can manage lessons for own courses" ON public.lessons;
DROP POLICY IF EXISTS "Admins can delete lessons" ON public.lessons;
DROP POLICY IF EXISTS "Admins can write lessons" ON public.lessons;
DROP POLICY IF EXISTS "Admins can update lessons" ON public.lessons;

CREATE POLICY "Teachers can manage lessons_insert" ON public.lessons FOR INSERT TO public WITH CHECK (get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']) OR EXISTS(SELECT 1 FROM courses c WHERE c.id = course_id AND c.instructor_id = (select auth.uid())));
CREATE POLICY "Teachers can manage lessons_update" ON public.lessons FOR UPDATE TO public USING (get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']) OR EXISTS(SELECT 1 FROM courses c WHERE c.id = course_id AND c.instructor_id = (select auth.uid())));
CREATE POLICY "Teachers can manage lessons_delete" ON public.lessons FOR DELETE TO public USING (get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']) OR EXISTS(SELECT 1 FROM courses c WHERE c.id = course_id AND c.instructor_id = (select auth.uid())));

-- notifications
DROP POLICY IF EXISTS "Users can manage own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Admins can insert notifications" ON public.notifications;

CREATE POLICY "Users manage notifications_select" ON public.notifications FOR SELECT TO authenticated USING (user_id = (select auth.uid()) OR get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']));
CREATE POLICY "Users manage notifications_update" ON public.notifications FOR UPDATE TO authenticated USING (user_id = (select auth.uid()) OR get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']));
CREATE POLICY "Users manage notifications_delete" ON public.notifications FOR DELETE TO authenticated USING (user_id = (select auth.uid()) OR get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']));
CREATE POLICY "Users manage notifications_insert" ON public.notifications FOR INSERT TO authenticated WITH CHECK (user_id = (select auth.uid()) OR get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']));

-- qr_codes
DROP POLICY IF EXISTS "Admins managed qr_codes" ON public.qr_codes;
DROP POLICY IF EXISTS "Users can redeem valid QR codes" ON public.qr_codes;

CREATE POLICY "Admins manage qr_codes_insert" ON public.qr_codes FOR INSERT TO authenticated WITH CHECK (get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']));
CREATE POLICY "Admins manage qr_codes_update" ON public.qr_codes FOR UPDATE TO authenticated USING (get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']));
CREATE POLICY "Admins manage qr_codes_delete" ON public.qr_codes FOR DELETE TO authenticated USING (get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']));
CREATE POLICY "Read qr codes" ON public.qr_codes FOR SELECT TO public USING (get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']) OR (((select auth.role()) = 'authenticated') AND (expires_at > now() OR expires_at IS NULL) AND is_redeemed = false AND is_active = true));

-- questions
DROP POLICY IF EXISTS "Teachers manage own exam questions" ON public.questions;
DROP POLICY IF EXISTS "Teachers can delete own exam questions" ON public.questions;
DROP POLICY IF EXISTS "Teachers can write own exam questions" ON public.questions;
DROP POLICY IF EXISTS "Teachers can update own exam questions" ON public.questions;

CREATE POLICY "Teachers can manage questions_insert" ON public.questions FOR INSERT TO public WITH CHECK (get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']) OR EXISTS(SELECT 1 FROM exams e JOIN teacher_courses tc ON e.course_id = tc.course_id WHERE e.id = exam_id AND tc.teacher_id = (select auth.uid())));
CREATE POLICY "Teachers can manage questions_update" ON public.questions FOR UPDATE TO public USING (get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']) OR EXISTS(SELECT 1 FROM exams e JOIN teacher_courses tc ON e.course_id = tc.course_id WHERE e.id = exam_id AND tc.teacher_id = (select auth.uid())));
CREATE POLICY "Teachers can manage questions_delete" ON public.questions FOR DELETE TO public USING (get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']) OR EXISTS(SELECT 1 FROM exams e JOIN teacher_courses tc ON e.course_id = tc.course_id WHERE e.id = exam_id AND tc.teacher_id = (select auth.uid())));

-- teacher_courses
DROP POLICY IF EXISTS "Admins manage teacher courses" ON public.teacher_courses;
DROP POLICY IF EXISTS "Admins can delete teacher courses" ON public.teacher_courses;
DROP POLICY IF EXISTS "Admins can write teacher courses" ON public.teacher_courses;
DROP POLICY IF EXISTS "Admins can update teacher courses" ON public.teacher_courses;
DROP POLICY IF EXISTS "View teacher courses" ON public.teacher_courses;

-- user_roles
DROP POLICY IF EXISTS "Admins manage user roles" ON public.user_roles;
DROP POLICY IF EXISTS "Users can view own roles" ON public.user_roles;

CREATE POLICY "Admins manage user roles_insert" ON public.user_roles FOR INSERT TO public WITH CHECK (get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']));
CREATE POLICY "Admins manage user roles_update" ON public.user_roles FOR UPDATE TO public USING (get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']));
CREATE POLICY "Admins manage user roles_delete" ON public.user_roles FOR DELETE TO public USING (get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']));
CREATE POLICY "View user roles" ON public.user_roles FOR SELECT TO public USING (user_id = (select auth.uid()) OR get_user_role((select auth.uid())) = ANY(ARRAY['admin','super_admin']));
