class Flashcard {
  final String id;
  final String front;
  final String back;
  final String? imageUrl;

  Flashcard({
    required this.id,
    required this.front,
    required this.back,
    this.imageUrl,
  });

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      id: json['id'] ?? '',
      front: json['front'] ?? '',
      back: json['back'] ?? '',
      imageUrl: json['image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'front': front,
      'back': back,
      'image_url': imageUrl,
    };
  }
}
