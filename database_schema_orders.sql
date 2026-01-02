-- ============================================
-- جدول الطلبات والاشتراكات (Orders)
-- ============================================

-- 1. جدول الاشتراكات (Subscription Plans)
CREATE TABLE public.subscription_plans (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT NULL,
  price DECIMAL(10,2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'SYP', -- العملة (SYP, USD)
  duration_months INTEGER NOT NULL DEFAULT 1, -- المدة بالأشهر
  is_popular BOOLEAN NOT NULL DEFAULT false,
  features JSONB NULL, -- قائمة الميزات
  max_courses INTEGER NULL, -- الحد الأقصى للكورسات
  max_downloads INTEGER NULL, -- الحد الأقصى للتحميلات
  has_offline_access BOOLEAN NOT NULL DEFAULT false,
  has_live_classes BOOLEAN NOT NULL DEFAULT false,
  has_exam_access BOOLEAN NOT NULL DEFAULT true,
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  
  CONSTRAINT subscription_plans_pkey PRIMARY KEY (id)
) TABLESPACE pg_default;

-- 2. جدول الطلبات (Orders)
CREATE TABLE public.orders (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  user_id UUID NOT NULL,
  order_number TEXT NOT NULL UNIQUE, -- رقم الطلب الفريد
  order_type TEXT NOT NULL DEFAULT 'subscription', -- subscription, course, bundle
  status TEXT NOT NULL DEFAULT 'pending', -- pending, confirmed, processing, completed, cancelled, refunded
  total_amount DECIMAL(10,2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'SYP',
  payment_method TEXT NULL, -- syriatel, mtn, bank_transfer, credit_card
  payment_status TEXT NOT NULL DEFAULT 'pending', -- pending, paid, failed, cancelled, refunded
  payment_transaction_id TEXT NULL, -- معرف المعاملة
  discount_code TEXT NULL,
  discount_amount DECIMAL(10,2) NULL DEFAULT 0,
  tax_amount DECIMAL(10,2) NULL DEFAULT 0,
  notes TEXT NULL,
  billing_address JSONB NULL, -- عنوان الفواتير
  shipping_address JSONB NULL, -- عنوان الشحن (للطلبات الفيزيائية)
  ordered_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
  paid_at TIMESTAMP WITHOUT TIME ZONE NULL,
  confirmed_at TIMESTAMP WITHOUT TIME ZONE NULL,
  cancelled_at TIMESTAMP WITHOUT TIME ZONE NULL,
  refunded_at TIMESTAMP WITHOUT TIME ZONE NULL,
  expires_at TIMESTAMP WITHOUT TIME ZONE NULL, -- تاريخ انتهاء الطلب
  created_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  
  CONSTRAINT orders_pkey PRIMARY KEY (id),
  CONSTRAINT orders_user_id_fkey FOREIGN KEY (user_id) 
    REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT orders_type_check CHECK (
    order_type = ANY (ARRAY[
      'subscription'::TEXT,
      'course'::TEXT,
      'bundle'::TEXT,
      'renewal'::TEXT,
      'upgrade'::TEXT
    ])
  ),
  CONSTRAINT orders_status_check CHECK (
    status = ANY (ARRAY[
      'pending'::TEXT,
      'confirmed'::TEXT,
      'processing'::TEXT,
      'completed'::TEXT,
      'cancelled'::TEXT,
      'refunded'::TEXT
    ])
  ),
  CONSTRAINT orders_payment_status_check CHECK (
    payment_status = ANY (ARRAY[
      'pending'::TEXT,
      'paid'::TEXT,
      'failed'::TEXT,
      'cancelled'::TEXT,
      'refunded'::TEXT,
      'partially_refunded'::TEXT
    ])
  ),
  CONSTRAINT orders_payment_method_check CHECK (
    payment_method = ANY (ARRAY[
      'syriatel'::TEXT,
      'mtn'::TEXT,
      'bank_transfer'::TEXT,
      'credit_card'::TEXT,
      'wallet'::TEXT,
      'free'::TEXT
    ])
  )
) TABLESPACE pg_default;

-- 3. جدول تفاصيل الطلبات (Order Items)
CREATE TABLE public.order_items (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  order_id UUID NOT NULL,
  item_type TEXT NOT NULL, -- subscription_plan, course, bundle
  item_id UUID NOT NULL, -- مرجع لجدول الخطة أو الكورس
  item_name TEXT NOT NULL,
  item_description TEXT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price DECIMAL(10,2) NOT NULL,
  total_price DECIMAL(10,2) NOT NULL,
  discount_amount DECIMAL(10,2) NULL DEFAULT 0,
  start_date DATE NULL, -- تاريخ البداية (للاشتراكات)
  end_date DATE NULL, -- تاريخ الانتهاء (للاشتراكات)
  features JSONB NULL, -- الميزات المضمنة
  created_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  
  CONSTRAINT order_items_pkey PRIMARY KEY (id),
  CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) 
    REFERENCES orders(id) ON DELETE CASCADE,
  CONSTRAINT order_items_type_check CHECK (
    item_type = ANY (ARRAY[
      'subscription_plan'::TEXT,
      'course'::TEXT,
      'bundle'::TEXT,
      'addon'::TEXT
    ])
  )
) TABLESPACE pg_default;

-- 4. جدول مدفوعات الطلبات (Order Payments)
CREATE TABLE public.order_payments (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  order_id UUID NOT NULL,
  payment_method TEXT NOT NULL,
  payment_provider TEXT NULL, -- syriatel, mtn, bank, stripe, paypal
  transaction_id TEXT NULL,
  payment_intent_id TEXT NULL, -- معرف الدفع من مزود الخدمة
  amount DECIMAL(10,2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'SYP',
  status TEXT NOT NULL DEFAULT 'pending', -- pending, processing, completed, failed, cancelled, refunded
  payment_date TIMESTAMP WITHOUT TIME ZONE NULL,
  failure_reason TEXT NULL,
  refund_amount DECIMAL(10,2) NULL DEFAULT 0,
  refund_reason TEXT NULL,
  created_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  
  CONSTRAINT order_payments_pkey PRIMARY KEY (id),
  CONSTRAINT order_payments_order_id_fkey FOREIGN KEY (order_id) 
    REFERENCES orders(id) ON DELETE CASCADE,
  CONSTRAINT order_payments_method_check CHECK (
    payment_method = ANY (ARRAY[
      'syriatel'::TEXT,
      'mtn'::TEXT,
      'bank_transfer'::TEXT,
      'credit_card'::TEXT,
      'wallet'::TEXT
    ])
  ),
  CONSTRAINT order_payments_status_check CHECK (
    status = ANY (ARRAY[
      'pending'::TEXT,
      'processing'::TEXT,
      'completed'::TEXT,
      'failed'::TEXT,
      'cancelled'::TEXT,
      'refunded'::TEXT,
      'partially_refunded'::TEXT
    ])
  )
) TABLESPACE pg_default;

-- 5. جدول اشتراكات المستخدمين (User Subscriptions)
CREATE TABLE public.user_subscriptions (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  user_id UUID NOT NULL,
  order_id UUID NOT NULL,
  subscription_plan_id UUID NOT NULL,
  status TEXT NOT NULL DEFAULT 'active', -- active, expired, cancelled, suspended
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  auto_renew BOOLEAN NOT NULL DEFAULT true,
  last_renewal_date DATE NULL,
  next_renewal_date DATE NULL,
  usage_stats JSONB NULL, -- إحصائيات الاستخدام
  max_courses INTEGER NULL,
  max_downloads INTEGER NULL,
  features JSONB NULL, -- الميزات المفعّلة
  created_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  
  CONSTRAINT user_subscriptions_pkey PRIMARY KEY (id),
  CONSTRAINT user_subscriptions_user_id_fkey FOREIGN KEY (user_id) 
    REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT user_subscriptions_order_id_fkey FOREIGN KEY (order_id) 
    REFERENCES orders(id) ON DELETE CASCADE,
  CONSTRAINT user_subscriptions_plan_id_fkey FOREIGN KEY (subscription_plan_id) 
    REFERENCES subscription_plans(id) ON DELETE CASCADE,
  CONSTRAINT user_subscriptions_status_check CHECK (
    status = ANY (ARRAY[
      'active'::TEXT,
      'expired'::TEXT,
      'cancelled'::TEXT,
      'suspended'::TEXT
    ])
  )
) TABLESPACE pg_default;

-- 6. جدول أكواد الخصم (Discount Codes)
CREATE TABLE public.discount_codes (
  id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT NULL,
  discount_type TEXT NOT NULL, -- percentage, fixed_amount
  discount_value DECIMAL(10,2) NOT NULL,
  min_order_amount DECIMAL(10,2) NULL DEFAULT 0,
  max_uses INTEGER NULL, -- الحد الأقصى للاستخدام
  used_count INTEGER NOT NULL DEFAULT 0,
  valid_from TIMESTAMP WITHOUT TIME ZONE NOT NULL,
  valid_until TIMESTAMP WITHOUT TIME ZONE NOT NULL,
  applicable_to TEXT NULL, -- subscription_plans, courses, all
  applicable_ids UUID[] NULL, -- معرفات العناصر المطبقة عليها
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
  
  CONSTRAINT discount_codes_pkey PRIMARY KEY (id),
  CONSTRAINT discount_codes_type_check CHECK (
    discount_type = ANY (ARRAY[
      'percentage'::TEXT,
      'fixed_amount'::TEXT
    ])
  )
) TABLESPACE pg_default;

-- ============================================
-- الفهارس (Indexes) لتحسين الأداء
-- ============================================

-- فهارس الاشتراكات
CREATE INDEX idx_subscription_plans_active ON public.subscription_plans(is_active);
CREATE INDEX idx_subscription_plans_popular ON public.subscription_plans(is_popular);
CREATE INDEX idx_subscription_plans_price ON public.subscription_plans(price);

-- فهارس الطلبات
CREATE INDEX idx_orders_user_id ON public.orders(user_id);
CREATE INDEX idx_orders_status ON public.orders(status);
CREATE INDEX idx_orders_payment_status ON public.orders(payment_status);
CREATE INDEX idx_orders_ordered_at ON public.orders(ordered_at);
CREATE INDEX idx_orders_number ON public.orders(order_number);
CREATE INDEX idx_orders_expires_at ON public.orders(expires_at);

-- فهارس تفاصيل الطلبات
CREATE INDEX idx_order_items_order_id ON public.order_items(order_id);
CREATE INDEX idx_order_items_type ON public.order_items(item_type);
CREATE INDEX idx_order_items_item_id ON public.order_items(item_id);

-- فهارس المدفوعات
CREATE INDEX idx_order_payments_order_id ON public.order_payments(order_id);
CREATE INDEX idx_order_payments_status ON public.order_payments(status);
CREATE INDEX idx_order_payments_transaction_id ON public.order_payments(transaction_id);

-- فهارس اشتراكات المستخدمين
CREATE INDEX idx_user_subscriptions_user_id ON public.user_subscriptions(user_id);
CREATE INDEX idx_user_subscriptions_status ON public.user_subscriptions(status);
CREATE INDEX idx_user_subscriptions_plan_id ON public.user_subscriptions(subscription_plan_id);
CREATE INDEX idx_user_subscriptions_end_date ON public.user_subscriptions(end_date);

-- فهارس أكواد الخصم
CREATE INDEX idx_discount_codes_code ON public.discount_codes(code);
CREATE INDEX idx_discount_codes_active ON public.discount_codes(is_active);
CREATE INDEX idx_discount_codes_valid_period ON public.discount_codes(valid_from, valid_until);

-- ============================================
-- Row Level Security (RLS) Policies
-- ============================================

-- تفعيل RLS على الجداول
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discount_codes ENABLE ROW LEVEL SECURITY;

-- سياسات خطط الاشتراك: يمكن للجميع القراءة للأصناف النشطة
CREATE POLICY "Everyone can read active subscription plans"
  ON public.subscription_plans FOR SELECT
  USING (is_active = true);

CREATE POLICY "Admins can manage subscription plans"
  ON public.subscription_plans FOR ALL
  USING (is_admin());

-- سياسات الطلبات: المستخدم يرى طلباته فقط
CREATE POLICY "Users can view own orders"
  ON public.orders FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create new orders"
  ON public.orders FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own orders"
  ON public.orders FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage all orders"
  ON public.orders FOR ALL
  USING (is_admin());

-- سياسات تفاصيل الطلبات
CREATE POLICY "Users can view order items for own orders"
  ON public.order_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM orders 
      WHERE orders.id = order_items.order_id 
      AND orders.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create order items for own orders"
  ON public.order_items FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders 
      WHERE orders.id = order_items.order_id 
      AND orders.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update order items for own orders"
  ON public.order_items FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM orders 
      WHERE orders.id = order_items.order_id 
      AND orders.user_id = auth.uid()
    )
  );

CREATE POLICY "Admins can manage all order items"
  ON public.order_items FOR ALL
  USING (is_admin());

-- سياسات المدفوعات
CREATE POLICY "Users can view payments for own orders"
  ON public.order_payments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM orders 
      WHERE orders.id = order_payments.order_id 
      AND orders.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create payments for own orders"
  ON public.order_payments FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders 
      WHERE orders.id = order_payments.order_id 
      AND orders.user_id = auth.uid()
    )
  );

CREATE POLICY "Admins can manage all payments"
  ON public.order_payments FOR ALL
  USING (is_admin());

-- سياسات اشتراكات المستخدمين
CREATE POLICY "Users can view own subscriptions"
  ON public.user_subscriptions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create subscriptions for themselves"
  ON public.user_subscriptions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own subscriptions"
  ON public.user_subscriptions FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage all subscriptions"
  ON public.user_subscriptions FOR ALL
  USING (is_admin());

-- سياسات أكواد الخصم
CREATE POLICY "Everyone can view active discount codes"
  ON public.discount_codes FOR SELECT
  USING (is_active = true);

CREATE POLICY "Admins can manage discount codes"
  ON public.discount_codes FOR ALL
  USING (is_admin());

-- ============================================
-- دوال مساعدة (Helper Functions)
-- ============================================

-- دالة لتوليد رقم الطلب
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TEXT AS $$
DECLARE
  year_part TEXT;
  month_part TEXT;
  sequence_part TEXT;
  order_number TEXT;
  sequence_num INTEGER;
BEGIN
  year_part := EXTRACT(year FROM NOW())::TEXT;
  month_part := LPAD(EXTRACT(month FROM NOW())::TEXT, 2, '0');
  
  -- الحصول على أعلى رقم تسلسلي لهذا الشهر
  SELECT COALESCE(MAX(
    CASE 
      WHEN order_number ~ '^' || year_part || month_part || '[0-9]{6}$'
      THEN CAST(SUBSTRING(order_number FROM 7) AS INTEGER)
      ELSE 0
    END
  ), 0) + 1
  INTO sequence_num
  FROM orders
  WHERE EXTRACT(year FROM ordered_at) = EXTRACT(year FROM NOW())
    AND EXTRACT(month FROM ordered_at) = EXTRACT(month FROM NOW());
  
  sequence_part := LPAD(sequence_num::TEXT, 6, '0');
  order_number := year_part || month_part || sequence_part;
  
  RETURN order_number;
END;
$$ LANGUAGE plpgsql;

-- دالة لحساب سعر بعد الخصم
CREATE OR REPLACE FUNCTION calculate_discounted_price(
  original_price DECIMAL,
  discount_code_param TEXT,
  order_amount DECIMAL DEFAULT 0
)
RETURNS DECIMAL AS $$
DECLARE
  discount_value DECIMAL;
  discount_type TEXT;
  min_order DECIMAL;
  current_time TIMESTAMP;
  discount_record RECORD;
BEGIN
  current_time := NOW();
  
  -- البحث عن كود الخصم
  SELECT * INTO discount_record
  FROM discount_codes
  WHERE code = discount_code_param
    AND is_active = true
    AND valid_from <= current_time
    AND valid_until >= current_time
    AND (max_uses IS NULL OR used_count
