-- إنشاء جدول إعدادات التطبيق
CREATE TABLE IF NOT EXISTS public.app_settings (
    setting_key TEXT PRIMARY KEY,
    setting_value TEXT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- تفعيل حماية الأسطر (RLS)
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- السماح لجميع المستخدمين المسجلين بقراءة الإعدادات
CREATE POLICY "Allow authenticated read access" 
ON public.app_settings FOR SELECT 
TO authenticated 
USING (true);

-- السماح للأدمن والسوبر أدمن فقط بتعديل الإعدادات
CREATE POLICY "Allow admin full access" 
ON public.app_settings FOR ALL 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.users u
    JOIN public.user_roles ur ON u.id = ur.user_id
    JOIN public.roles r ON ur.role_id = r.id
    WHERE u.id = auth.uid() AND r.name IN ('admin', 'super_admin')
  )
);

-- إدخال القيمة الافتراضية
INSERT INTO public.app_settings (setting_key, setting_value)
VALUES ('screenshot_protection_enabled', 'false')
ON CONFLICT (setting_key) DO NOTHING;
