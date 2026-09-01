// lib/models/announcement_model.dart
enum AnnouncementPriority { normal, important, urgent }
enum AnnouncementAudienceType { all, role, specificUser }

class Announcement {
  final int id;  // ✅ Changed from String to int
  final String title;
  final String message;
  final AnnouncementPriority priority;
  final AnnouncementAudienceType audienceType;
  final String? audienceRole;
  final int? audienceUserId;
  final DateTime createdAt;
  final bool isSent;

  Announcement({
    required this.id,
    required this.title,
    required this.message,
    required this.priority,
    required this.audienceType,
    this.audienceRole,
    this.audienceUserId,
    required this.createdAt,
    this.isSent = false,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'message': message,
    'priority': priority.name,
    'audienceType': audienceType.name,
    'audienceRole': audienceRole,
    'audienceUserId': audienceUserId,
  };

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as int,  // ✅ Parse as int
      title: json['title'] as String,
      message: json['message'] as String,
      priority: AnnouncementPriority.values.firstWhere(
            (e) => e.name == json['priority'],
        orElse: () => AnnouncementPriority.normal,
      ),
      audienceType: AnnouncementAudienceType.values.firstWhere(
            (e) => e.name == json['audienceType'],
        orElse: () => AnnouncementAudienceType.all,
      ),
      audienceRole: json['audienceRole'] as String?,
      audienceUserId: json['audienceUserId'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isSent: json['isSent'] as bool? ?? false,
    );
  }
}