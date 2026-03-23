class BannerAd {
  final String id;
  final String title;
  final String? subtitle;
  final String imageUrl;
  final String type; // 'ad', 'course', 'package', 'external'
  final String location; // 'top', 'bottom'
  final String? targetId; // could be course_id or package_id
  final String? linkUrl; // for external links
  final DateTime createdAt;

  BannerAd({
    required this.id,
    required this.title,
    this.subtitle,
    required this.imageUrl,
    required this.type,
    this.location = 'top',
    this.targetId,
    this.linkUrl,
    required this.createdAt,
  });

  factory BannerAd.fromJson(Map<String, dynamic> json) {
    return BannerAd(
      id: json['id'],
      title: json['title'],
      subtitle: json['subtitle'],
      imageUrl: json['image_url'],
      type: json['type'] ?? 'ad',
      location: json['location'] ?? 'top',
      targetId: json['target_id'],
      linkUrl: json['link_url'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subtitle': subtitle,
      'image_url': imageUrl,
      'type': type,
      'location': location,
      'target_id': targetId,
      'link_url': linkUrl,
    };
  }
}
