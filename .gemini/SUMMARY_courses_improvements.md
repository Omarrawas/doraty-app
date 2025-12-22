# 🎯 ملخص التحسينات المطلوبة - شاشة إدارة الدورات

## ✅ ما تم حتى الآن

### 1. **إضافة Bio للمدرس** ✅
- ✅ حقل Bio في نموذج التعديل
- ✅ حفظ Bio في قاعدة البيانات
- ⏳ **مطلوب في Supabase:**
  ```sql
  ALTER TABLE public.users ADD COLUMN IF NOT EXISTS bio TEXT NULL;
  ```

### 2. **تحميل بيانات المدرس لكل دورة** ✅
- ✅ تم تحديث `_loadCourses()` 
- ✅ جلب معلومات المدرس من `teacher_courses`
- ✅ إضافة import لـ `SupabaseService`

---

## 🔧 التحسينات المطلوبة للبطاقة

### عرض المعلومات التالية في بطاقة الدورة:

```
┌────────────────────────────────────────┐
│ فيزياء - الصف الثالث الثانوي  [منشور] │
│ علمي                                   │
│                                        │
│ مقدمة شاملة للفيزياء...               │
│                                        │
│ [👤 أحمد محمد]  [علمي]                │
│                                        │
│ [الدروس]  [الاختبارات]                │
│ [تعديل]  [📊]  [🗑️]                   │
└────────────────────────────────────────┘
```

### المعلومات المطلوب عرضها:

1. **العنوان** (موجود ✅)
2. **الوصف** (موجود ✅)
3. **الحالة**: منشور/مسودة (موجود ✅)
4. **الفرع**: علمي/أدبي (جديد ⭐)
5. **اسم المدرس** أو "غير محدد" (جديد ⭐)

---

## 📋 الكود المطلوب إضافته

### في بطاقة الدورة بعد الوصف:

```dart
const SizedBox(height: 12),

// Teacher and Branch info
Row(
  children: [
    // Teacher info
    Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.blue.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.person,
              size: 16,
              color: Colors.blue.shade700,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                course['teacher'] != null
                    ? course['teacher']['full_name'] ?? 'غير محدد'
                    : 'غير محدد',
                style: TextStyle(
                  fontSize: 12,
                  color: course['teacher'] != null
                      ? Colors.blue.shade700
                      : Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ),
    const SizedBox(width: 8),
    // Branch info
    if (course['branch'] != null)
      Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.purple.withOpacity(0.2),
          ),
        ),
        child: Text(
          course['branch'],
          style: TextStyle(
            fontSize: 12,
            color: Colors.purple.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
  ],
),
```

---

## 🎨 التصميم المحسّن

### الألوان:
- **المدرس**: صندوق أزرق فاتح with icon 👤
- **الفرع**: صندوق بنفسجي فاتح
- **منشور**: أخضر
- **مسودة**: برتقالي

### الترتيب:
1. العنوان والحالة (صف واحد)
2. الفئة (category)
3. الوصف (2 أسطر max)
4. **المدرس والفرع** (صف واحد) ⭐ جديد
5. أزرار الإجراءات

---

## 💡 ملاحظات مهمة

### 1. حقل `branch` في جدول `courses`

هل موجود في جدول `courses`؟ **تحقق من ذلك!**

إذا **لم يكن موجوداً**، نفذ:
```sql
ALTER TABLE public.courses 
ADD COLUMN IF NOT EXISTS branch TEXT NULL;

-- إضافة check constraint
ALTER TABLE public.courses
ADD CONSTRAINT courses_branch_check 
CHECK (branch IS NULL OR branch IN ('علمي', 'أدبي'));
```

### 2. العلاقة بين teacher_courses و users

تأكد من وجود foreign key constraint:
```sql
-- يجب أن يكون موجوداً:
ALTER TABLE public.teacher_courses
ADD CONSTRAINT teacher_courses_teacher_id_fkey
FOREIGN KEY (teacher_id) REFERENCES users(id) ON DELETE CASCADE;
```

---

## ✅ الخلاصة

### مطلوب منك في Supabase:

```sql
-- 1. إضافة Bio
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS bio TEXT NULL;

-- 2. إضافة Branch للدورات (إن لم يكن موجوداً)
ALTER TABLE public.courses 
ADD COLUMN IF NOT EXISTS branch TEXT NULL;

-- 3. (اختياري) حذف instructor_id إذا كان موجوداً
ALTER TABLE public.courses 
DROP COLUMN IF EXISTS instructor_id;
```

### في التطبيق:

✅ تم: تحميل بيانات المدرس
⏳ مطلوب: إضافة الكود في بطاقة الدورة (يدوياً)

**الموقع**: بعد السطر 276 في `_buildCourseCard`

---

**بعد تنفيذ SQL في Supabase، هل تريد مني:**
1. توضيح أين بالضبط تضيف الكود في البطاقة؟
2. أم إنشاء ملف جديد كامل للشاشة؟

أخبرني! 🚀
