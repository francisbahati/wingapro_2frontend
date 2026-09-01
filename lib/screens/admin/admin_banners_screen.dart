// lib/screens/admin/admin_banners_screen.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/banner_service.dart';
import '../../services/error_handler.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/error_view.dart';
import '../../models/banner_model.dart' as BannerModel;
import '../../widgets/error_snackbar.dart';

class AdminBannersScreen extends StatefulWidget {
  const AdminBannersScreen({super.key});

  @override
  State<AdminBannersScreen> createState() => _AdminBannersScreenState();
}

class _AdminBannersScreenState extends State<AdminBannersScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  final BannerService _bannerService = BannerService();
  final ImagePicker _imagePicker = ImagePicker();
  List<BannerModel.Banner> _banners = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

  @override
  void initState() {
    super.initState();
    _fetchBanners();
  }

  Future<void> _fetchBanners() async {
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
        '${ApiConfig.baseUrl}/api/admin/banners',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final list = data['banners'] as List? ?? [];
          if (mounted) {
            setState(() {
              _banners = list.map((json) => BannerModel.Banner.fromJson(json)).toList();
              _isLoading = false;
            });
          }
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load banners',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchBanners);
      if (mounted) {
        setState(() {
          _errorTitle = info.title;
          _errorMessage = info.message;
          _retryAction = info.action;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteBanner(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Banner'),
        content: const Text('Are you sure you want to delete this banner?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isSubmitting = true);
    try {
      final token = await _auth.getToken();
      final response = await _api.delete(
        context,
        '${ApiConfig.baseUrl}/api/admin/banners/$id',
      );
      if (response.statusCode == 200) {
        _fetchBanners();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Banner deleted'), backgroundColor: Colors.green),
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to delete',
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─── Safe image picker with error handling ───
  Future<File?> _pickImage() async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (picked == null) return null;
      final file = File(picked.path);
      if (!await file.exists()) {
        throw Exception('Selected image file not found.');
      }
      return file;
    } catch (e) {
      showErrorSnackbar(context, e);
      return null;
    }
  }

  Future<File?> _cropImage(File image) async {
    try {
      CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 2, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Banner',
            toolbarColor: const Color(0xFF0A2E5C),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Banner',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: true,
          ),
        ],
      );
      if (cropped == null) return null;
      final croppedFile = File(cropped.path);
      if (!await croppedFile.exists()) {
        throw Exception('Cropped image file not found.');
      }
      return croppedFile;
    } catch (e) {
      debugPrint('Cropping failed: $e – using original.');
      return image;
    }
  }

  void _showAddBannerDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleController = TextEditingController();
    bool isActive = true;
    File? _selectedImage;
    String? _imageUrl;
    String? _imageKey; // NEW: store the R2 key

    showDialog(
      context: context,
      barrierDismissible: !_isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Add Banner'),
          backgroundColor: isDark
              ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey.shade300.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          content: Container(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      // Disable interaction during upload
                      setStateDialog(() => _isSubmitting = true);
                      try {
                        final file = await _pickImage();
                        if (file == null) {
                          setStateDialog(() => _isSubmitting = false);
                          return;
                        }

                        final cropped = await _cropImage(file);
                        if (cropped == null) {
                          setStateDialog(() => _isSubmitting = false);
                          return;
                        }

                        // Show the cropped image
                        setStateDialog(() {
                          _selectedImage = cropped;
                          _imageUrl = null;
                          _imageKey = null;
                        });

                        // Upload to server
                        final result = await _bannerService.uploadImage(cropped);
                        setStateDialog(() {
                          _imageUrl = result['imageUrl'];
                          _imageKey = result['key']; // ✅ Store the key
                          _isSubmitting = false;
                        });
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Image uploaded successfully'), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        setStateDialog(() => _isSubmitting = false);
                        showErrorSnackbar(ctx, e);
                      }
                    },
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.grey.shade400,
                        ),
                      ),
                      child: _selectedImage != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image, size: 60),
                        ),
                      )
                          : (_imageUrl != null && _imageUrl!.isNotEmpty)
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _imageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image, size: 60),
                        ),
                      )
                          : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            size: 50,
                            color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to select & crop image',
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (v) => setStateDialog(() => isActive = v),
                    tileColor: Colors.transparent,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : () async {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Title is required'), backgroundColor: Colors.red),
                  );
                  return;
                }
                if (_imageUrl == null || _imageUrl!.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please select and upload an image'), backgroundColor: Colors.red),
                  );
                  return;
                }
                if (_imageKey == null || _imageKey!.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Image key missing – please re-upload'), backgroundColor: Colors.red),
                  );
                  return;
                }
                setStateDialog(() => _isSubmitting = true);
                try {
                  final body = {
                    'title': title,
                    'imageUrl': _imageUrl!,
                    'key': _imageKey!, // ✅ Send the key
                    'link': null,
                    'order': 0,
                    'isActive': isActive,
                  };
                  final response = await _api.post(
                    ctx,
                    '${ApiConfig.baseUrl}/api/admin/banners',
                    body: body,
                  );
                  final data = jsonDecode(response.body);
                  if (response.statusCode == 201 && data['success'] == true) {
                    Navigator.pop(ctx);
                    _fetchBanners();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Banner created!'), backgroundColor: Colors.green),
                      );
                    }
                  } else {
                    throw ApiException(
                      statusCode: response.statusCode,
                      message: data['message'] ?? 'Creation failed',
                    );
                  }
                } catch (e) {
                  showErrorSnackbar(ctx, e);
                  setStateDialog(() => _isSubmitting = false);
                }
              },
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create'),
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
          title: const Text('Manage Banners'),
          backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
          elevation: 0,
          actions: [
            IconButton(icon: const Icon(Icons.add), onPressed: _showAddBannerDialog),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchBanners),
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
        title: const Text('Manage Banners'),
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddBannerDialog),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchBanners),
        ],
      ),
      body: _isLoading
          ? ListView.builder(
        itemCount: 3,
        itemBuilder: (_, __) => const SkeletonListTile(),
      )
          : _banners.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No banners created yet.'),
            const SizedBox(height: 8),
            const Text('Tap + to add a promotional banner.'),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchBanners,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _banners.length,
          itemBuilder: (ctx, i) {
            final b = _banners[i];
            return GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.85),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    b.imageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image, size: 60),
                  ),
                ),
                title: Text(
                  b.title,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  b.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
                trailing: IconButton(
                  icon: _isSubmitting
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.delete, color: Colors.red),
                  onPressed: _isSubmitting ? null : () => _deleteBanner(b.id),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}