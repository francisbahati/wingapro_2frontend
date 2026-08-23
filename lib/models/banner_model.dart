// lib/models/banner_model.dart
class Banner {
  final int id;
  final String title;
  final String imageUrl;
  final String? link;
  final int order;
  final bool isActive;
  final DateTime createdAt;

  Banner({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.link,
    required this.order,
    required this.isActive,
    required this.createdAt,
  });

  factory Banner.fromJson(Map<String, dynamic> json) {
    return Banner(
      id: json['id'],
      title: json['title'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      link: json['link'],
      order: json['order'] ?? 0,
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}