# 🚀 أمثلة عملية لاستخدام Cache في التطبيق

## 📦 كيفية الاستخدام:

### 1️⃣ في DatabaseService - جلب الدورات مع Cache

**قبل (بدون Cache):**
```dart
Future<List<Map<String, dynamic>>> getCourses() async {
  // كل مرة يحمل من Supabase
  final response = await _client
      .from('courses')
      .select('*');
  return List<Map<String, dynamic>>.from(response);
}
```

**بعد (مع Cache):**
```dart
import 'cache_service.dart';

Future<List<Map<String, dynamic>>> getCourses({int page = 0}) async {
  return await fetchWithCache(
    key: CacheKeys.courses(page: page),
    duration: const Duration(minutes: 15), // Cache لمدة 15 دقيقة
    fetcher: () async {
      final response = await _client
          .from('courses')
          .select('''
            id,
            title,
            thumbnail_url,
            price,
            instructor_name
          ''') // فقط المعلومات الأساسية
          .range(page * 20, (page + 1) * 20 - 1) // Pagination
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    },
  );
}
```

**النتيجة:**
- أول مرة: يحمل من Supabase ✅
- المرات التالية (خلال 15 دقيقة): يحمل من الـ Cache ⚡
- **توفير: 95% من الـ requests!**

---

### 2️⃣ في CourseDetailsScreen - جلب تفاصيل الدورة

```dart
class _CourseDetailsScreenState extends State<CourseDetailsScreen> {
  Map<String, dynamic>? _courseData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCourse();
  }

  Future<void> _loadCourse() async {
    setState(() => _isLoading = true);

    try {
      final dbService = DatabaseService();
      
      // استخدام Cache
      final course = await fetchWithCache(
        key: CacheKeys.course(widget.courseId),
        duration: const Duration(minutes: 30), // Cache لمدة 30 دقيقة
        fetcher: () => dbService.getCourseById(widget.courseId),
      );

      setState(() {
        _courseData = course;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Handle error
    }
  }

  // عند التحديث (Pull to refresh)
  Future<void> _refresh() async {
    // مسح الـ Cache لهذه الدورة
    CacheService().remove(CacheKeys.course(widget.courseId));
    
    // إعادة التحميل
    await _loadCourse();
  }
}
```

---

### 3️⃣ في LessonScreen - تحميل الأسئلة والملاحظات

```dart
class _LessonScreenState extends State<LessonScreen> {
  List<Map<String, dynamic>>? _questions;
  List<Map<String, dynamic>>? _notes;

  Future<void> _loadQuestions() async {
    if (_questions != null) return; // Already loaded

    final dbService = DatabaseService();
    
    // استخدام Cache للأسئلة
    final questions = await fetchWithCache(
      key: CacheKeys.lessonQuestions(widget.lesson.id),
      duration: const Duration(hours: 1), // الأسئلة لا تتغير كثيراً
      fetcher: () => dbService.getLessonQuestions(widget.lesson.id),
    );

    setState(() => _questions = questions);
  }

  Future<void> _loadNotes() async {
    if (_notes != null) return;

    final dbService = DatabaseService();
    
    // الملاحظات قد تتغير، فـ Cache أقصر
    final notes = await fetchWithCache(
      key: CacheKeys.lessonNotes(widget.lesson.id),
      duration: const Duration(minutes: 5),
      fetcher: () => dbService.getLessonNotes(widget.lesson.id),
    );

    setState(() => _notes = notes);
  }

  // عند إضافة ملاحظة جديدة
  Future<void> _addNote(String content) async {
    final dbService = DatabaseService();
    await dbService.addNote(widget.lesson.id, content);
    
    // مسح الـ Cache لتحديث القائمة
    CacheService().remove(CacheKeys.lessonNotes(widget.lesson.id));
    
    // إعادة التحميل
    setState(() => _notes = null);
    await _loadNotes();
  }
}
```

---

### 4️⃣ في PaymentScreen - جلب حسابات الدفع

```dart
class _PaymentScreenState extends State<PaymentScreen> {
  List<PaymentAccount> _paymentAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadPaymentAccounts();
  }

  Future<void> _loadPaymentAccounts() async {
    final accounts = await fetchWithCache(
      key: CacheKeys.paymentAccounts,
      duration: const Duration(hours: 24), // معلومات الحسابات ثابتة
      fetcher: () async {
        final dbService = DatabaseService();
        return await dbService.getPaymentAccounts();
      },
    );

    setState(() {
      _paymentAccounts = accounts
          .map((json) => PaymentAccount.fromJson(json))
          .toList();
    });
  }
}
```

---

### 5️⃣ في ProfileScreen - جلب بيانات المستخدم

```dart
class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;

  Future<void> _loadUserData() async {
    final dbService = DatabaseService();
    final userId = dbService.currentUserId;
    
    if (userId == null) return;

    final userData = await fetchWithCache(
      key: CacheKeys.userProfile(userId),
      duration: const Duration(minutes: 10),
      fetcher: () => dbService.getUserProfile(userId),
    );

    setState(() => _userData = userData);
  }

  // عند تحديث البروفايل
  Future<void> _updateProfile(Map<String, dynamic> updates) async {
    final dbService = DatabaseService();
    await dbService.updateUserProfile(updates);
    
    // مسح الـ Cache
    final userId = dbService.currentUserId!;
    CacheService().remove(CacheKeys.userProfile(userId));
    
    // إعادة التحميل
    await _loadUserData();
  }
}
```

---

## 📊 نظام ذكي للـ Cache

### مدة الـ Cache حسب نوع البيانات:

```dart
// بيانات ثابتة نادراً ما تتغير
Duration.hours(24):
  - حسابات الدفع
  - خطط الاشتراك
  - الإعدادات العامة

// بيانات متوسطة التغيير
Duration.minutes(30):
  - قائمة الدورات
  - تفاصيل الدورة
  - قائمة الدروس

// بيانات سريعة التغيير
Duration.minutes(5):
  - الملاحظات الشخصية
  - التقدم في الدورة
  - الإشعارات

// بدون Cache
null:
  - إضافة/تعديل/حذف بيانات
  - البحث
  - الإيصالات قيد المراجعة (للمشرف)
```

---

## 🧹 مسح الـ Cache

### 1. مسح تلقائي عند الخروج من التطبيق

```dart
// في main.dart
class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // التطبيق في الخلفية - مسح الـ Cache المنتهي
      CacheService().clearExpired();
    }
  }
}
```

### 2. مسح يدوي من الإعدادات

```dart
// في SettingsScreen
ListTile(
  leading: Icon(Icons.delete_sweep),
  title: Text('مسح الذاكرة المؤقتة'),
  subtitle: Text('لتحرير مساحة'),
  onTap: () {
    final cache = CacheService();
    final stats = cache.getStats();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('مسح الذاكرة المؤقتة'),
        content: Text(
          'سيتم مسح ${stats['total_items']} عنصر من الذاكرة المؤقتة'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              cache.clear();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تم المسح بنجاح')),
              );
            },
            child: Text('مسح'),
          ),
        ],
      ),
    );
  },
)
```

### 3. مسح عند تحديث البيانات

```dart
// عند إضافة ملاحظة جديدة
Future<void> addNote(String lessonId, String content) async {
  await _client.from('notes').insert({
    'lesson_id': lessonId,
    'content': content,
  });
  
  // مسح Cache الملاحظات لهذا الدرس
  CacheService().remove(CacheKeys.lessonNotes(lessonId));
}

// عند تحديث بيانات المستخدم
Future<void> updateUserProfile(Map<String, dynamic> updates) async {
  final userId = currentUserId!;
  
  await _client
      .from('users')
      .update(updates)
      .eq('id', userId);
  
  // مسح Cache البروفايل
  CacheService().remove(CacheKeys.userProfile(userId));
}
```

---

## 📈 مراقبة الأداء

### إحصائيات الـ Cache

```dart
// في DevToolsScreen أو DebugScreen
class CacheStatsWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cache = CacheService();
    final stats = cache.getStats();
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📊 إحصائيات الذاكرة المؤقتة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('العناصر المحفوظة: ${stats['total_items']}'),
            Text('متوسط العمر: ${stats['average_age_seconds']}ث'),
            Text('الأقدم: ${stats['oldest_item_seconds']}ث'),
            Text('الأحدث: ${stats['newest_item_seconds']}ث'),
            SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => cache.printStats(),
                  child: Text('طباعة التفاصيل'),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => cache.clearExpired(),
                  child: Text('مسح المنتهية'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 🎯 النتيجة المتوقعة:

### بدون Cache:
```
100 مستخدم × 10 زيارات/يوم × 30 يوم = 30,000 request/شهر
30,000 × 50 KB = 1.5 GB bandwidth ⚠️
```

### مع Cache:
```
100 مستخدم × 10 زيارات/يوم × 30 يوم = 30,000 request
70% من الـ requests من الـ Cache = 9,000 requests فقط
9,000 × 50 KB = 450 MB bandwidth ✅
```

**توفير: 70% من الـ Bandwidth!**

---

## ✅ Quick Start - ابدأ الآن:

### 1. استورد الـ CacheService
```dart
import 'package:doraty/core/services/cache_service.dart';
```

### 2. استبدل دوال DatabaseService
```dart
// بدلاً من:
final courses = await dbService.getCourses();

// استخدم:
final courses = await fetchWithCache(
  key: CacheKeys.courses(),
  fetcher: () => dbService.getCourses(),
);
```

### 3. مسح الـ Cache عند التحديث
```dart
// بعد أي insert/update/delete:
CacheService().remove(CacheKeys.courses());
```

**جاهز! 🚀**
