// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final auth = AuthService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildGlassCard(
            context,
            child: ListTile(
              leading: Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
                color: const Color(0xFF0A2E5C),
              ),
              title: const Text('Dark Mode'),
              trailing: Switch(
                value: themeProvider.isDark,
                onChanged: (_) => themeProvider.toggleTheme(),
                activeColor: const Color(0xFF0A2E5C),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildGlassCard(
            context,
            child: ListTile(
              leading: const Icon(Icons.info_outline,
                  color: Color(0xFF0A2E5C)),
              title: const Text('Version'),
              subtitle: const Text('1.0.0'),
              trailing: const Icon(Icons.chevron_right, size: 20,
                  color: Colors.grey),
            ),
          ),
          const SizedBox(height: 12),
          _buildGlassCard(
            context,
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              trailing: const Icon(Icons.chevron_right, size: 20,
                  color: Colors.grey),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    backgroundColor: isDark
                        ? const Color(0xFF0A1A2B).withOpacity(0.95)
                        : Colors.white.withOpacity(0.95),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.15)
                            : Colors.grey.shade300.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        child: const Text('Logout',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await auth.logout();
                  NotificationService().stopPolling();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard(BuildContext context, {required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 0,
      color: isDark
          ? const Color(0xFF0A1A2B).withOpacity(0.95)
          : Colors.white.withOpacity(0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? Colors.white.withOpacity(0.15)
              : Colors.grey.shade300.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: child,
    );
  }
}