-- ============================================
-- نظام التحقق اليدوي من الدفع
-- Manual Payment Verification System
-- ============================================

-- 1. جدول إعدادات حسابات الدفع (للمشرف)
CREATE TABLE IF NOT EXISTS public.payment_accounts (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  payment_method TEXT NOT NULL, -- syriatel_cash, mtn_cash, sham_cash
  account_name TEXT NOT NULL,
  account_number TEXT NOT NULL,
  account_details JSONB NULL, -- معلومات إضافية
  instructions TEXT NULL, -- تعليمات للمستخدم
  is_active BOOLEAN NOT NULL DEFAULT true,
  display_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  
  CONSTRAINT payment_accounts_pkey PRIMARY KEY (id),
  CONSTRAINT payment_accounts_method_unique UNIQUE (payment_method)
);

-- 2. جدول إيصالات الدفع
CREATE TABLE IF NOT EXISTS public.payment_receipts (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  order_id UUID NOT NULL,
  user_id UUID NOT NULL,
  payment_method TEXT NOT NULL,
  transaction_id TEXT NULL, -- رقم العملية المدخل من المستخدم
  receipt_image_url TEXT NULL, -- رابط صورة الإيصال
  phone_number TEXT NULL, -- رقم الهاتف المستخدم في الدفع
  amount DECIMAL(10,2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending', -- pending, approved, rejected
  admin_notes TEXT NULL, -- ملاحظات المشرف
  reviewed_by UUID NULL, -- المشرف الذي راجع
  reviewed_at TIMESTAMP WITHOUT TIME ZONE NULL,
  created_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  
  CONSTRAINT payment_receipts_pkey PRIMARY KEY (id),
  CONSTRAINT payment_receipts_order_fkey FOREIGN KEY (order_id) 
    REFERENCES orders(id) ON DELETE CASCADE,
  CONSTRAINT payment_receipts_user_fkey FOREIGN KEY (user_id) 
    REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT payment_receipts_status_check CHECK (
    status = ANY (ARRAY[
      'pending'::TEXT,
      'approved'::TEXT,
      'rejected'::TEXT,
      'under_review'::TEXT
    ])
  )
);

-- 3. الفهارس
CREATE INDEX IF NOT EXISTS idx_payment_receipts_order_id ON public.payment_receipts(order_id);
CREATE INDEX IF NOT EXISTS idx_payment_receipts_user_id ON public.payment_receipts(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_receipts_status ON public.payment_receipts(status);
CREATE INDEX IF NOT EXISTS idx_payment_receipts_created_at ON public.payment_receipts(created_at);

-- 4. Row Level Security
ALTER TABLE public.payment_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_receipts ENABLE ROW LEVEL SECURITY;

-- سياسات payment_accounts: الجميع يقرأ، المشرف فقط يعدل
CREATE POLICY "Everyone can view active payment accounts"
  ON public.payment_accounts FOR SELECT
  USING (is_active = true);

CREATE POLICY "Admins can manage payment accounts"
  ON public.payment_accounts FOR ALL
  USING (is_admin());

-- سياسات payment_receipts: المستخدم يرى إيصالاته، المشرف يرى الكل
CREATE POLICY "Users can view own receipts"
  ON public.payment_receipts FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create receipts for own orders"
  ON public.payment_receipts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own pending receipts"
  ON public.payment_receipts FOR UPDATE
  USING (auth.uid() = user_id AND status = 'pending');

CREATE POLICY "Admins can manage all receipts"
  ON public.payment_receipts FOR ALL
  USING (is_admin());

-- 5. دالة لتحديث حالة الطلب عند الموافقة على الدفع
CREATE OR REPLACE FUNCTION approve_payment_receipt(
  receipt_id_param UUID,
  admin_notes_param TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  receipt_record RECORD;
  order_record RECORD;
BEGIN
  -- جلب معلومات الإيصال
  SELECT * INTO receipt_record
  FROM payment_receipts
  WHERE id = receipt_id_param;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Receipt not found';
  END IF;
  
  -- جلب معلومات الطلب
  SELECT * INTO order_record
  FROM orders
  WHERE id = receipt_record.order_id;
  
  -- تحديث حالة الإيصال
  UPDATE payment_receipts
  SET 
    status = 'approved',
    admin_notes = admin_notes_param,
    reviewed_by = auth.uid(),
    reviewed_at = NOW(),
    updated_at = NOW()
  WHERE id = receipt_id_param;
  
  -- تحديث حالة الطلب
  UPDATE orders
  SET 
    payment_status = 'paid',
    status = 'completed',
    paid_at = NOW(),
    confirmed_at = NOW(),
    updated_at = NOW()
  WHERE id = receipt_record.order_id;
  
  -- تفعيل الاشتراك إذا كان الطلب اشتراك
  IF order_record.order_type = 'subscription' THEN
    -- سيتم التعامل مع هذا في الكود
    NULL;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. دالة لرفض الدفع
CREATE OR REPLACE FUNCTION reject_payment_receipt(
  receipt_id_param UUID,
  admin_notes_param TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  receipt_record RECORD;
BEGIN
  -- جلب معلومات الإيصال
  SELECT * INTO receipt_record
  FROM payment_receipts
  WHERE id = receipt_id_param;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Receipt not found';
  END IF;
  
  -- تحديث حالة الإيصال
  UPDATE payment_receipts
  SET 
    status = 'rejected',
    admin_notes = admin_notes_param,
    reviewed_by = auth.uid(),
    reviewed_at = NOW(),
    updated_at = NOW()
  WHERE id = receipt_id_param;
  
  -- تحديث حالة الطلب
  UPDATE orders
  SET 
    payment_status = 'failed',
    status = 'cancelled',
    cancelled_at = NOW(),
    updated_at = NOW()
  WHERE id = receipt_record.order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. إدخال حسابات دفع تجريبية (يمكن تعديلها لاحقاً)
INSERT INTO public.payment_accounts (payment_method, account_name, account_number, instructions, is_active, display_order)
VALUES 
  (
    'syriatel_cash',
    'سيريتل كاش',
    '0933000000',
    'قم بتحويل المبلغ إلى رقم الهاتف الموضح، ثم التقط صورة للإيصال أو أدخل رقم العملية',
    true,
    1
  ),
  (
    'mtn_cash',
    'MTN كاش',
    '0944000000',
    'قم بتحويل المبلغ إلى رقم الهاتف الموضح، ثم التقط صورة للإيصال أو أدخل رقم العملية',
    true,
    2
  ),
  (
    'sham_cash',
    'شام كاش - بنك الشام',
    '1234567890',
    'قم بتحويل المبلغ عبر تطبيق شام كاش إلى رقم الحساب الموضح، ثم التقط صورة للإيصال أو أدخل رقم العملية',
    true,
    3
  )
ON CONFLICT (payment_method) DO NOTHING;

-- 8. Storage bucket لحفظ صور الإيصالات
-- يتم إنشاؤه عبر Supabase Dashboard أو API:
-- Bucket name: payment-receipts
-- Public: false (خاص فقط بالمستخدم والمشرف)
-- 1. إنشاء الجدول
CREATE TABLE IF NOT EXISTS public.enrollments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
    
    -- حالة الاشتراك: (نشط، منتهي، ملغي)
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'expired', 'cancelled')),
    
    -- التواريخ
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ, -- يمكن تركه فارغاً للاشتراكات الدائمة
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- منع التكرار: لا يمكن للطالب الاشتراك في نفس الدورة أكثر من مرة في نفس الوقت
    UNIQUE(user_id, course_id)
);

-- 2. إضافة سياسات الحماية (RLS - Row Level Security)
ALTER TABLE public.enrollments ENABLE ROW LEVEL SECURITY;

-- سياسة: الطلاب يمكنهم رؤية اشتراكاتهم الخاصة فقط
CREATE POLICY "Users can view their own enrollments"
ON public.enrollments FOR SELECT
USING (auth.uid() = user_id);

-- سياسة: الأدمن يمكنه رؤية جميع الاشتراكات والتحكم بها
CREATE POLICY "Admins have full access to enrollments"
ON public.enrollments FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM user_roles 
        JOIN roles ON user_roles.role_id = roles.id 
        WHERE user_roles.user_id = auth.uid() 
        AND roles.name = 'super_admin'
    )
);

-- 3. تفعيل التحديث التلقائي لحقل updated_at (اختياري)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_enrollments_updated_at
    BEFORE UPDATE ON public.enrollments
    FOR EACH ROW
    EXECUTE PROCEDURE update_updated_at_column();