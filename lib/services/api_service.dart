import '../models/course.dart';
import '../models/user.dart';

class ApiService {
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Mock data for now - will be replaced with Supabase calls
  Future<List<Course>> getCourses() async {
    await Future.delayed(const Duration(seconds: 1));
    return [
      Course(
        id: '1',
        title: 'دورة الرياضيات المتقدمة - البكالوريا',
        description: 'دورة شاملة تغطي جميع مواضيع الرياضيات للبكالوريا العلمي',
        instructorName: 'الأستاذ محمد أحمد',
        instructorPhoto: 'https://i.pravatar.cc/150?img=12',
        imageUrl:
            'https://images.unsplash.com/photo-1635070041078-e363dbe005cb',
        price: 75000,
        rating: 4.8,
        studentsCount: 1234,
        lessonsCount: 48,
        durationHours: '24 ساعة',
        category: 'علمي',
        subject: 'رياضيات',
        curriculum: [],
      ),
      Course(
        id: '2',
        title: 'الفيزياء الشاملة للثانوية العامة',
        description: 'كل ما تحتاجه لإتقان الفيزياء',
        instructorName: 'الدكتور أحمد حسن',
        instructorPhoto: 'https://i.pravatar.cc/150?img=13',
        imageUrl:
            'https://images.unsplash.com/photo-1636466497217-26a8cbeaf0aa',
        price: 65000,
        rating: 4.9,
        studentsCount: 987,
        lessonsCount: 36,
        durationHours: '18 ساعة',
        category: 'علمي',
        subject: 'فيزياء',
        curriculum: [],
      ),
      Course(
        id: '3',
        title: 'اللغة العربية - القواعد والنصوص',
        description: 'شرح مبسط وشامل لقواعد اللغة العربية',
        instructorName: 'الأستاذة سارة علي',
        instructorPhoto: 'https://i.pravatar.cc/150?img=5',
        imageUrl: 'https://images.unsplash.com/photo-1546410531-bb4caa6b424d',
        price: 50000,
        rating: 4.7,
        studentsCount: 850,
        lessonsCount: 30,
        durationHours: '15 ساعة',
        category: 'أدبي',
        subject: 'لغة عربية',
        curriculum: [],
      ),
    ];
  }

  Future<AppUser?> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 2));
    // Mock login
    if (email.isNotEmpty && password.isNotEmpty) {
      return AppUser(
        id: 'user_123',
        name: 'أحمد محمود',
        email: email,
        branch: 'علمي',
        createdAt: DateTime.now(),
      );
    }
    return null;
  }
}
