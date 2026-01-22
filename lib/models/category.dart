class Category {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int coursesCount;

  Category({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.coursesCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'coursesCount': coursesCount,
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      icon: json['icon'],
      coursesCount: json['coursesCount'] ?? 0,
    );
  }
}
