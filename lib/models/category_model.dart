class CategoryModel {
  final String id;
  final String name;
  final String? nameEn; // Added nameEn
  final String slug;
  final String? parentId;
  final String? iconUrl;

  CategoryModel({
    required this.id,
    required this.name,
    this.nameEn,
    required this.slug,
    this.parentId,
    this.iconUrl,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nameEn: json['name_en']?.toString(),
      slug: json['slug']?.toString() ?? '',
      parentId: json['parent_id']?.toString(),
      iconUrl: json['icon_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_en': nameEn,
      'slug': slug,
      'parent_id': parentId,
      'icon_url': iconUrl,
    };
  }

  String getLocalizedName(String locale) {
    if (locale == 'en' && nameEn != null && nameEn!.isNotEmpty) {
      return nameEn!;
    }
    return name;
  }
}
