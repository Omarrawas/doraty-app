# Changelog / سجل التغييرات

## [1.1.6+19] - 2026-03-19

### English
#### Added
- **New Category Courses Screen**: Users can now browse courses by main and sub-categories with a modern segment filter bar.
- **Admin Category Management**: Admins can now manage the category hierarchy (parent/child relationships) directly from the dashboard.
- **Sub-category Filtering**: Integrated horizontal scrollable sub-category chips for better navigation.

#### Changed
- **Refined CourseCard UI**: Enlarged thumbnails and simplified layout for a more premium look.
- **Prominent Subscription Button**: Larger and more visible primary action buttons on course cards.
- **Dynamic Subjects Screen**: Categories are now fetched in real-time from Supabase instead of being hardcoded.

#### Fixed
- Resolved multiple linting errors and import issues across the project.
- Fixed `parent_id` update logic in `DatabaseService`.

---

### العربية
#### الإضافات
- **شاشة دورات التصنيف الجديدة**: يمكن للمستخدمين الآن تصفح الدورات حسب التصنيفات الرئيسية والفرعية مع شريط فلترة حديث.
- **إدارة التصنيفات للأدمن**: يمكن للمشرفين الآن إدارة التسلسل الهرمي للتصنيفات (علاقة الأب بالابن) مباشرة من لوحة التحكم.
- **فلترة التصنيفات الفرعية**: إضافة رقائق (chips) أفقية قابلة للتمرير للتصنيفات الفرعية لتحسين التصفح.

#### التغييرات
- **تحسين واجهة بطاقة الدورة**: تكبير الصور المصغرة وتبسيط التخطيط لمظهر أكثر فخامة.
- **زر اشتراك بارز**: أزرار إجراء أولية أكبر وأكثر وضوحًا في بطاقات الدورات.
- **شاشة المواد الديناميكية**: يتم الآن جلب التصنيفات في الوقت الفعلي من Supabase بدلاً من كونها ثابتة.

#### الإصلاحات
- حل العديد من أخطاء الـ lint ومشاكل الاستيراد في المشروع.
- إصلاح منطق تحديث `parent_id` في خدمة قاعدة البيانات.
