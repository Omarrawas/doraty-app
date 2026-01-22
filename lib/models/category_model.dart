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
      id: json['id'],
      name: json['name'],
      nameEn: json['name_en'],
      slug: json['slug'],
      parentId: json['parent_id'],
      iconUrl: json['icon_url'],
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
