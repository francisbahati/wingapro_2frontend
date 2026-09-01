// lib/widgets/profile_header.dart
import 'package:flutter/material.dart';
import 'glass_card.dart';

class ProfileHeader extends StatelessWidget {
  final String username;
  final String? email;
  final String? phone;
  final String? role;
  final String? branch;
  final String? avatarUrl;
  final bool showChangeAvatar;
  final Function(String)? onAvatarChanged;
  // These parameters are kept for backward compatibility, but are not used in the UI
  final bool showGreeting;
  final String? greeting;

  const ProfileHeader({
    super.key,
    required this.username,
    this.email,
    this.phone,
    this.role,
    this.branch,
    this.avatarUrl,
    this.showChangeAvatar = false,
    this.onAvatarChanged,
    this.showGreeting = true,
    this.greeting,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: isDark
          ? const Color(0xFF0A1A2B).withOpacity(0.95)
          : Colors.white.withOpacity(0.92),
      borderColor: isDark
          ? const Color(0xFF1A3A6A).withOpacity(0.5)
          : Colors.blue.shade100.withOpacity(0.5),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: isDark ? const Color(0xFF1A3A6A) : const Color(0xFF0A2E5C),
                backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                    ? NetworkImage(avatarUrl!)
                    : null,
                child: avatarUrl == null || avatarUrl!.isEmpty
                    ? Text(
                  username[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                )
                    : null,
              ),
              if (showChangeAvatar)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {
                      if (onAvatarChanged != null) {
                        // Implement avatar picker logic here
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0A2E5C),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Column with details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0A2E5C),
                  ),
                ),
                if (email != null && email!.isNotEmpty)
                  Text(
                    email!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                if (phone != null && phone!.isNotEmpty)
                  Text(
                    phone!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                if (branch != null && branch!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Branch: $branch',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                if (role != null)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A2E5C).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      role!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF0A2E5C),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}