// lib/screens/admin/admin_announcements_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/announcement_model.dart';
import '../../widgets/glass_card.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/auth_service.dart';
import '../../services/error_handler.dart';
import '../../widgets/error_view.dart';
import '../../widgets/error_snackbar.dart';

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  List<Announcement> _announcements = [];
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
  }

  Future<void> _fetchAnnouncements() async {
    setState(() {
      _isLoading = true;
      _errorTitle = null;
      _errorMessage = null;
      _retryAction = null;
    });
    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');
      final response = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/admin/announcements',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final list = data['announcements'] as List? ?? [];
          setState(() {
            _announcements = list.map((json) => Announcement.fromJson(json)).toList();
            _isLoading = false;
          });
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load announcements',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchAnnouncements);
      setState(() {
        _errorTitle = info.title;
        _errorMessage = info.message;
        _retryAction = info.action;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAnnouncement(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Announcement'),
        content: const Text('Are you sure you want to delete this announcement?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final token = await _auth.getToken();
      final response = await _api.delete(
        context,
        '${ApiConfig.baseUrl}/api/admin/announcements/$id',
      );
      if (response.statusCode == 200) {
        _fetchAnnouncements();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement deleted'), backgroundColor: Colors.green),
        );
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to delete',
        );
      }
    } catch (e) {
      showErrorSnackbar(context, e);
    }
  }

  // ─── Create announcement dialog ───
  void _showCreateAnnouncementDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    AnnouncementPriority selectedPriority = AnnouncementPriority.normal;
    AnnouncementAudienceType selectedAudienceType = AnnouncementAudienceType.all;
    String? selectedRole;
    int? selectedUserId;
    bool isSending = false;

    showDialog(
      context: context,
      barrierDismissible: !isSending,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('New Announcement'),
          backgroundColor: isDark
              ? const Color(0xFF0A1A2B).withOpacity(0.95)
              : Colors.white.withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? Colors.white.withOpacity(0.15)
                  : Colors.grey.shade300.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          content: SingleChildScrollView(
            child: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageController,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Message *'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AnnouncementPriority>(
                    value: selectedPriority,
                    items: AnnouncementPriority.values.map((p) {
                      String label = p.name.toUpperCase();
                      return DropdownMenuItem(
                        value: p,
                        child: Row(
                          children: [
                            Icon(
                              p == AnnouncementPriority.urgent
                                  ? Icons.priority_high
                                  : p == AnnouncementPriority.important
                                  ? Icons.warning
                                  : Icons.info,
                              color: p == AnnouncementPriority.urgent
                                  ? Colors.red
                                  : p == AnnouncementPriority.important
                                  ? Colors.orange
                                  : Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Text(label),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setStateDialog(() => selectedPriority = v!),
                    decoration: const InputDecoration(labelText: 'Priority'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AnnouncementAudienceType>(
                    value: selectedAudienceType,
                    items: AnnouncementAudienceType.values.map((a) {
                      String label = a.name.replaceAll('_', ' ').toUpperCase();
                      return DropdownMenuItem(
                        value: a,
                        child: Text(label),
                      );
                    }).toList(),
                    onChanged: (v) => setStateDialog(() {
                      selectedAudienceType = v!;
                      selectedRole = null;
                      selectedUserId = null;
                    }),
                    decoration: const InputDecoration(labelText: 'Audience'),
                  ),
                  const SizedBox(height: 12),
                  if (selectedAudienceType == AnnouncementAudienceType.role)
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      items: ['customer', 'seller', 'admin', 'staff']
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (v) => setStateDialog(() => selectedRole = v!),
                      decoration: const InputDecoration(labelText: 'Select Role'),
                    ),
                  if (selectedAudienceType == AnnouncementAudienceType.specificUser)
                    Column(
                      children: [
                        TextField(
                          keyboardType: TextInputType.number,
                          onChanged: (v) => setStateDialog(() {
                            selectedUserId = int.tryParse(v);
                          }),
                          decoration: const InputDecoration(
                            labelText: 'User ID (numeric)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (selectedUserId != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Selected User ID: $selectedUserId',
                              style: const TextStyle(color: Colors.green),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSending
                  ? null
                  : () async {
                final title = titleController.text.trim();
                final message = messageController.text.trim();
                if (title.isEmpty || message.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Please fill in title and message'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }
                if (selectedAudienceType == AnnouncementAudienceType.role &&
                    selectedRole == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Please select a role'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }
                if (selectedAudienceType == AnnouncementAudienceType.specificUser &&
                    selectedUserId == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter a valid user ID'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }
                setStateDialog(() => isSending = true);
                try {
                  final body = {
                    'title': title,
                    'message': message,
                    'priority': selectedPriority.name,
                    'audienceType': selectedAudienceType.name,
                    'audienceRole': selectedRole,
                    'audienceUserId': selectedUserId,
                  };
                  final response = await _api.post(
                    ctx,
                    '${ApiConfig.baseUrl}/api/admin/announcements',
                    body: body,
                  );
                  final data = jsonDecode(response.body);
                  if (response.statusCode == 201 && data['success'] == true) {
                    Navigator.pop(ctx);
                    _fetchAnnouncements();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Announcement sent!'),
                          backgroundColor: Colors.green),
                    );
                  } else {
                    throw ApiException(
                      statusCode: response.statusCode,
                      message: data['message'] ?? 'Failed to create announcement',
                    );
                  }
                } catch (e) {
                  showErrorSnackbar(ctx, e);
                  setStateDialog(() => isSending = false);
                }
              },
              child: isSending
                  ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_errorTitle != null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('Announcements'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchAnnouncements),
          ],
        ),
        body: ErrorView(
          title: _errorTitle!,
          message: _errorMessage!,
          onRetry: _retryAction,
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Announcements'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchAnnouncements),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _announcements.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.announcement, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No announcements yet.'),
            Text('Tap + to create one.'),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchAnnouncements,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _announcements.length,
          itemBuilder: (ctx, i) {
            final a = _announcements[i];
            Color priorityColor;
            IconData priorityIcon;
            switch (a.priority) {
              case AnnouncementPriority.urgent:
                priorityColor = Colors.red;
                priorityIcon = Icons.priority_high;
                break;
              case AnnouncementPriority.important:
                priorityColor = Colors.orange;
                priorityIcon = Icons.warning;
                break;
              default:
                priorityColor = Colors.blue;
                priorityIcon = Icons.info;
            }
            String audienceLabel;
            switch (a.audienceType) {
              case AnnouncementAudienceType.all:
                audienceLabel = 'All Users';
                break;
              case AnnouncementAudienceType.role:
                audienceLabel = 'Role: ${a.audienceRole ?? 'N/A'}';
                break;
              case AnnouncementAudienceType.specificUser:
                audienceLabel = 'User ID: ${a.audienceUserId ?? 'N/A'}';
                break;
            }
            return GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withOpacity(0.85)
                  : Colors.white.withOpacity(0.85),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(priorityIcon, color: priorityColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          a.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(
                          a.priority.name.toUpperCase(),
                          style: TextStyle(
                            color: priorityColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        backgroundColor: priorityColor.withOpacity(0.1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    a.message,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.people, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        audienceLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(a.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteAnnouncement(a.id),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateAnnouncementDialog,
        backgroundColor: const Color(0xFF0A2E5C),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}