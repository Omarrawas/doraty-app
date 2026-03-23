class Category {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int coursesCount;
  final String? parentId;

  Category({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.coursesCount = 0,
    this.parentId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'coursesCount': coursesCount,
      if (parentId != null) 'parentId': parentId,
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      icon: json['icon'],
      coursesCount: json['coursesCount'] ?? 0,
      parentId: json['parentId'],
    );
  }
}
