enum Branch {
  scientific,
  literary,
}

extension BranchExtension on Branch {
  String get name {
    switch (this) {
      case Branch.scientific:
        return 'الفرع العلمي';
      case Branch.literary:
        return 'الفرع الأدبي';
    }
  }

  String get description {
    switch (this) {
      case Branch.scientific:
        return 'رياضيات، فيزياء، كيمياء، أحياء';
      case Branch.literary:
        return 'تاريخ، جغرافيا، فلسفة، علم اجتماع';
    }
  }

  List<String> get subjects {
    switch (this) {
      case Branch.scientific:
        return [
          'الرياضيات',
          'الفيزياء',
          'الكيمياء',
          'الأحياء',
          'اللغة العربية',
          'اللغة الإنجليزية',
          'اللغة الفرنسية',
          'الديانة',
        ];
      case Branch.literary:
        return [
          'التاريخ',
          'الجغرافيا',
          'الفلسفة',
          'علم الاجتماع',
          'اللغة العربية',
          'اللغة الإنجليزية',
          'اللغة الفرنسية',
          'الديانة',
        ];
    }
  }
}

class Category {
  final String id;
  final String name;
  final String description;
  final Branch branch;
  final String icon;
  final int coursesCount;

  Category({
    required this.id,
    required this.name,
    required this.description,
    required this.branch,
    required this.icon,
    this.coursesCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'branch': branch.toString(),
      'icon': icon,
      'coursesCount': coursesCount,
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      branch: Branch.values.firstWhere(
        (e) => e.toString() == json['branch'],
      ),
      icon: json['icon'],
      coursesCount: json['coursesCount'] ?? 0,
    );
  }
}
