// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../services/token_service.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';
import '../models/user.dart';
import '../utils/responsive_utils.dart';
import 'contact_support_screen.dart';  
import 'pricing_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isChangingPassword = false;
  bool _isUploadingImage = false;

  Map<String, dynamic> _userInfo = {};
  User? _currentUser;
  File? _pendingProfileImage;
  final ImagePicker _picker = ImagePicker();

  // Profile form controllers
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _hospitalCtrl = TextEditingController();
  final _specialtyCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  // Password form controllers
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  String? _profileError;
  String? _passwordError;
  bool _isSaving = false;
  bool _isUpdatingPassword = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  static const _specialties = [
    'Cardiologist',
    'General Practitioner',
    'Internist',
    'Emergency Physician',
    'Nurse',
    'Radiologist',
    'Other'
  ];

  static const _countries = [
    'Algeria',
    'France',
    'United States',
    'United Kingdom',
    'Canada',
    'Germany',
    'Morocco',
    'Tunisia',
    'Egypt',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _licenseCtrl.dispose();
    _hospitalCtrl.dispose();
    _specialtyCtrl.dispose();
    _countryCtrl.dispose();
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        final userInfo = await ApiService.getMe(token);
        _currentUser = await TokenService.getUser();
        final fullName = '${userInfo['first_name'] ?? ''} ${userInfo['last_name'] ?? ''}'.trim();
        setState(() {
          _userInfo = userInfo;
          _fullNameCtrl.text = fullName;
          _phoneCtrl.text = userInfo['phone'] ?? '';
          _licenseCtrl.text = userInfo['license_number'] ?? '';
          _hospitalCtrl.text = userInfo['hospital'] ?? '';
          _specialtyCtrl.text = userInfo['specialty'] ?? '';
          _countryCtrl.text = userInfo['country'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickProfileImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _pendingProfileImage = File(image.path));
    }
  }

  Future<void> _uploadProfileImage(File imageFile) async {
    setState(() => _isUploadingImage = true);
    
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/upload-profile-picture'),
      );
      
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        setState(() {
          _userInfo['profile_picture'] = result['profile_picture'];
          _isUploadingImage = false;
          _pendingProfileImage = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully'),
            backgroundColor: AppColors.sageGreen,
          ),
        );
        
        await _fetchProfile();
      } else {
        throw Exception('Upload failed');
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    setState(() { _isSaving = true; _profileError = null; });
    
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        if (_pendingProfileImage != null) {
          await _uploadProfileImage(_pendingProfileImage!);
        }
        
        final fullName = _fullNameCtrl.text.trim();
        final nameParts = fullName.split(' ');
        final firstName = nameParts.first;
        final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
        
        final isDoctor = _currentUser?.role == 'doctor';
        
        await ApiService.updateProfile(
          token: token,
          firstName: firstName,
          lastName: lastName,
          phone: _phoneCtrl.text.trim(),
          hospital: _hospitalCtrl.text.trim(),
          specialty: _specialtyCtrl.text.trim(),
          country: isDoctor ? _countryCtrl.text.trim() : null,
        );
        
        setState(() { 
          _isEditing = false; 
          _isSaving = false;
          _pendingProfileImage = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.sageGreen,
          ),
        );
        
        await _fetchProfile();
      }
    } catch (e) {
      setState(() { 
        _profileError = 'Failed to update profile'; 
        _isSaving = false;
      });
    }
  }
  
  Future<void> _changePassword() async {
    setState(() => _passwordError = null);

    if (_newPasswordCtrl.text != _confirmPasswordCtrl.text) {
      setState(() => _passwordError = 'New passwords do not match');
      return;
    }
    final pw = _newPasswordCtrl.text;
    if (pw.length < 8) {
      setState(() => _passwordError = 'Password must be at least 8 characters');
      return;
    }
    if (!pw.contains(RegExp(r'[A-Z]'))) {
      setState(() => _passwordError = 'Include at least 1 uppercase letter');
      return;
    }
    if (!pw.contains(RegExp(r'[0-9]'))) {
      setState(() => _passwordError = 'Include at least 1 number');
      return;
    }
    if (!pw.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      setState(() => _passwordError = 'Include at least 1 special character');
      return;
    }

    setState(() => _isUpdatingPassword = true);
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        await ApiService.changePassword(
          token: token,
          currentPassword: _currentPasswordCtrl.text,
          newPassword: pw,
        );
        setState(() {
          _isChangingPassword = false;
          _isUpdatingPassword = false;
          _currentPasswordCtrl.clear();
          _newPasswordCtrl.clear();
          _confirmPasswordCtrl.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully'),
            backgroundColor: AppColors.sageGreen,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _passwordError = 'Current password is incorrect';
        _isUpdatingPassword = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final t = AppThemeTokens.of(context);
        return AlertDialog(
          backgroundColor: t.surface,
          title: Text('Logout', style: TextStyle(color: t.textPrimary)),
          content: Text('Are you sure you want to logout?',
              style: TextStyle(color: t.textMuted)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: t.textPrimary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await TokenService.deleteToken();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  // ========== ASSISTANT INFO ==========
  Widget _buildAssistantInfo(AppThemeTokens t) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _getAssistantInfo(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        
        final assistant = snapshot.data;
        if (assistant != null && assistant['has_assistant'] == true) {
          final firstName = assistant['first_name'] ?? '';
          final lastName = assistant['last_name'] ?? '';
          final fullName = '$firstName $lastName'.trim();
          final email = assistant['email'] ?? 'Not set';
          final phone = assistant['phone'];
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Assistant',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: t.card.withOpacity(t.isDark ? 1.0 : 0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: t.border),
                  boxShadow: [
                    BoxShadow(
                      color: t.textPrimary.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(icon: Icons.person_outline, label: 'Name', value: fullName.isEmpty ? 'Not set' : fullName, t: t),
                    Divider(height: 20, thickness: 0.5, color: t.border),
                    _InfoRow(icon: Icons.email_outlined, label: 'Email', value: email, t: t),
                    if (phone != null && phone.isNotEmpty) ...[
                      Divider(height: 20, thickness: 0.5, color: t.border),
                      _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: phone, t: t),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => _showRemoveAssistantDialog(),
                        icon: const Icon(Icons.person_remove, size: 18),
                        label: const Text('Remove Assistant', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade400,
                          side: BorderSide(color: Colors.red.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        
        return const SizedBox.shrink();
      },
    );
  }

  Future<Map<String, dynamic>?> _getAssistantInfo() async {
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        final response = await http.get(
          Uri.parse('${AppConfig.baseUrl}/doctor/assistant'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting assistant: $e');
      return null;
    }
  }

  void _showRemoveAssistantDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final t = AppThemeTokens.of(context);
        return AlertDialog(
          backgroundColor: t.surface,
          title: Text('Remove Assistant', style: TextStyle(color: t.textPrimary)),
          content: Text(
            'Are you sure you want to remove your assistant? '
            'They will no longer have access to your patients and predictions.',
            style: TextStyle(color: t.textMuted),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: t.textPrimary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove'),
            ),
          ],
        );
      }
    );
    
    if (confirm == true) {
      try {
        final token = await TokenService.getToken();
        if (token != null) {
          await ApiService.doctorRemoveAssistant(token);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Assistant removed successfully')),
          );
          _fetchProfile();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // ========== CONTACT SUPPORT ==========
  void _goToContactSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ContactSupportScreen()),
    );
  }

  Widget _buildContactSupportButton(AppThemeTokens t) {
    return GestureDetector(
      onTap: _goToContactSupport,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: t.card.withOpacity(t.isDark ? 1.0 : 0.75),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.border),
          boxShadow: [
            BoxShadow(
              color: t.textPrimary.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.sageGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.support_agent_rounded,
                  color: AppColors.sageGreen, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contact Support',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Have a question or issue? Contact our support team.',
                    style: TextStyle(
                      fontSize: 13,
                      color: t.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: t.textMuted),
          ],
        ),
      ),
    );
  }

  // ========== BUILD ==========
  @override
  Widget build(BuildContext context) {
    final t = AppThemeTokens.of(context);
    final r = Responsive.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final provider = context.watch<ThemeProvider>();

    String? profilePicPath = _userInfo['profile_picture'];
    String? fullImageUrl;
    if (profilePicPath != null && profilePicPath.isNotEmpty && _pendingProfileImage == null) {
      fullImageUrl = '${AppConfig.baseUrl}$profilePicPath';
    }

    final isDoctor = _currentUser?.role == 'doctor';
    final isAssistant = _currentUser?.role == 'assistant';
    final isAdmin = _currentUser?.role == 'admin';
    final showFullInfo = isDoctor || isAdmin;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text('Profile', style: TextStyle(color: t.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: t.textPrimary,
        centerTitle: false,
        actions: [
          GestureDetector(
            onTap: () => provider.toggleTheme(),
            child: Container(
              width: r.wp(36),
              height: r.wp(36),
              margin: EdgeInsets.only(right: r.wp(8)),
              decoration: BoxDecoration(
                color: t.surface.withOpacity(t.isDark ? 0.15 : 0.7),
                borderRadius: BorderRadius.circular(r.sp(10)),
                border: Border.all(color: t.border),
              ),
              child: Icon(
                provider.isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                color: t.textPrimary.withOpacity(0.72),
                size: r.wp(18),
              ),
            ),
          ),
          if (!_isEditing && !_isChangingPassword)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.sageGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit_outlined, size: 20),
              ),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800), // Responsive Max Width for Web
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // Profile Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.sageGreen.withOpacity(0.08),
                              AppColors.sageGreen.withOpacity(0.02),
                            ],
                          ),
                        ),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _isEditing ? _pickProfileImage : null,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: _isUploadingImage
                                          ? Container(
                                              width: 110,
                                              height: 110,
                                              color: AppColors.sageGreen,
                                              child: const Center(
                                                child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            )
                                          : (_pendingProfileImage != null
                                              ? Image.file(
                                                  _pendingProfileImage!,
                                                  width: 110,
                                                  height: 110,
                                                  fit: BoxFit.cover,
                                                )
                                              : (fullImageUrl != null
                                                  ? Image.network(
                                                      fullImageUrl,
                                                      width: 110,
                                                      height: 110,
                                                      fit: BoxFit.cover,
                                                      loadingBuilder: (context, child, loadingProgress) {
                                                        if (loadingProgress == null) return child;
                                                        return Container(
                                                          width: 110,
                                                          height: 110,
                                                          color: AppColors.sageGreen,
                                                          child: const Center(
                                                            child: CircularProgressIndicator(
                                                              color: Colors.white,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      errorBuilder: (context, error, stackTrace) {
                                                        return _buildDefaultAvatar();
                                                      },
                                                    )
                                                  : _buildDefaultAvatar())),
                                    ),
                                  ),
                                  if (_isEditing)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.sageGreen,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _fullNameCtrl.text,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: t.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.sageGreen.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                isDoctor ? 'Doctor' : (isAssistant ? 'Assistant' : 'Admin'),
                                style: const TextStyle(
                                  color: AppColors.sageGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isEditing) ...[
                              _buildEditForm(t),
                            ] else ...[
                              _buildInfoSection(t),
                              
                              // Assistant info (only for doctors)
                              if (_currentUser?.role == 'doctor') ...[
                                const SizedBox(height: 24),
                                _buildAssistantInfo(t),
                              ],
                              
                              if (showFullInfo) ...[
                                const SizedBox(height: 24),
                                _buildProfessionalInfoSection(t),
                              ],
                              
                              const SizedBox(height: 24),
                              _buildSecuritySection(t),

                              const SizedBox(height: 24),
                              _buildSubscriptionInfo(t),
                              const SizedBox(height: 16),
                              _buildContactSupportButton(t),
                            ],
                            const SizedBox(height: 32),
                            if (!_isEditing && !_isChangingPassword)
                              _buildLogoutButton(bottomPadding),
                            SizedBox(height: bottomPadding + 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 110, height: 110,
      color: AppColors.sageGreen,
      child: const Icon(Icons.person_rounded, size: 50, color: Colors.white),
    );
  }

  Widget _buildInfoSection(AppThemeTokens t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: t.border)),
          color: t.card.withOpacity(t.isDark ? 1.0 : 0.8),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _InfoRow(icon: Icons.email_outlined,
                    label: 'Email',
                    value: _userInfo['email'] ?? 'Not set',
                    t: t),
                Divider(height: 20, thickness: 0.5, color: t.border),
                _InfoRow(icon: Icons.person_outline,
                    label: 'Full Name',
                    value: _fullNameCtrl.text.isEmpty ? 'Not set' : _fullNameCtrl.text,
                    t: t),
                Divider(height: 20, thickness: 0.5, color: t.border),
                _InfoRow(icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: _userInfo['phone'] ?? 'Not set',
                    t: t),
                if (_currentUser?.role == 'assistant') ...[
                  Divider(height: 20, thickness: 0.5, color: t.border),
                  _InfoRow(icon: Icons.medical_services_rounded,
                      label: 'Role',
                      value: 'Assistant',
                      t: t),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfessionalInfoSection(AppThemeTokens t) {
    final isDoctor = _currentUser?.role == 'doctor';
    final isAdmin = _currentUser?.role == 'admin';
    
    if (!isDoctor && !isAdmin) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Professional Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: t.border)),
          color: t.card.withOpacity(t.isDark ? 1.0 : 0.8),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _InfoRow(icon: Icons.badge_outlined,
                    label: 'License',
                    value: _userInfo['license_number'] ?? 'Not set',
                    t: t),
                Divider(height: 20, thickness: 0.5, color: t.border),
                _InfoRow(icon: Icons.local_hospital_outlined,
                    label: 'Hospital',
                    value: _userInfo['hospital'] ?? 'Not set',
                    t: t),
                Divider(height: 20, thickness: 0.5, color: t.border),
                _InfoRow(icon: Icons.medical_services_outlined,
                    label: 'Specialty',
                    value: _userInfo['specialty'] ?? 'Not set',
                    t: t),
                if (isDoctor) ...[
                  Divider(height: 20, thickness: 0.5, color: t.border),
                  _InfoRow(icon: Icons.flag_outlined,
                      label: 'Country',
                      value: _userInfo['country'] ?? 'Not set',
                      t: t),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildEditForm(AppThemeTokens t) {
    final isDoctor = _currentUser?.role == 'doctor';
    final isAdmin = _currentUser?.role == 'admin';
    final showFullInfo = isDoctor || isAdmin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Edit Profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 20),
        
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: t.card.withOpacity(t.isDark ? 1.0 : 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.border),
          ),
          child: Column(
            children: [
              if (_profileError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_profileError!,
                              style: const TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
              _buildTextField(_fullNameCtrl, 'Full Name', Icons.person_outline, t: t),
              const SizedBox(height: 16),
              _buildTextField(_phoneCtrl, 'Phone Number', Icons.phone_outlined,
                  keyboardType: TextInputType.phone, t: t),
              if (showFullInfo) ...[
                const SizedBox(height: 16),
                _buildTextField(_licenseCtrl, 'License Number', Icons.badge_outlined, t: t),
                const SizedBox(height: 16),
                _buildTextField(_hospitalCtrl, 'Hospital', Icons.local_hospital_outlined, t: t),
                const SizedBox(height: 16),
                _buildSpecialtyDropdown(t),
                if (isDoctor) ...[
                  const SizedBox(height: 16),
                  _buildCountryDropdown(t),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                    _pendingProfileImage = null;
                  });
                  _fetchProfile();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: t.textPrimary,
                  side: BorderSide(color: t.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sageGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildSpecialtyDropdown(AppThemeTokens t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AppLabel('Specialty', t),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: t.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _specialtyCtrl.text.isNotEmpty &&
                      _specialties.contains(_specialtyCtrl.text)
                  ? _specialtyCtrl.text
                  : null,
              hint: Text('Select specialty',
                  style: TextStyle(color: t.textMuted)),
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  color: t.textMuted),
              dropdownColor: t.surface,
              borderRadius: BorderRadius.circular(14),
              style: TextStyle(color: t.textPrimary, fontSize: 15),
              items: _specialties
                  .map((e) =>
                      DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _specialtyCtrl.text = value ?? ''),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCountryDropdown(AppThemeTokens t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AppLabel('Country', t),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: t.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _countryCtrl.text.isNotEmpty &&
                      _countries.contains(_countryCtrl.text)
                  ? _countryCtrl.text
                  : null,
              hint: Text('Select country',
                  style: TextStyle(color: t.textMuted)),
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  color: t.textMuted),
              dropdownColor: t.surface,
              borderRadius: BorderRadius.circular(14),
              style: TextStyle(color: t.textPrimary, fontSize: 15),
              items: _countries
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _countryCtrl.text = value ?? ''),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySection(AppThemeTokens t) {
    if (_isChangingPassword) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Change Password',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: t.card.withOpacity(t.isDark ? 1.0 : 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: t.border),
            ),
            child: Column(
              children: [
                if (_passwordError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_passwordError!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                _buildPasswordField(_currentPasswordCtrl,
                    'Current Password', _obscureCurrent,
                    () => setState(
                        () => _obscureCurrent = !_obscureCurrent),
                    t),
                const SizedBox(height: 16),
                _buildPasswordField(_newPasswordCtrl, 'New Password',
                    _obscureNew,
                    () => setState(() => _obscureNew = !_obscureNew),
                    t),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    'Min 8 chars, 1 uppercase, 1 number, 1 special character',
                    style: TextStyle(
                        color: t.textMuted, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 16),
                _buildPasswordField(_confirmPasswordCtrl,
                    'Confirm New Password', _obscureConfirm,
                    () => setState(
                        () => _obscureConfirm = !_obscureConfirm),
                    t),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _isChangingPassword = false;
                    _passwordError = null;
                    _currentPasswordCtrl.clear();
                    _newPasswordCtrl.clear();
                    _confirmPasswordCtrl.clear();
                  }),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: t.textPrimary,
                    side: BorderSide(color: t.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      _isUpdatingPassword ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sageGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: _isUpdatingPassword
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Security',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => setState(() => _isChangingPassword = true),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: t.card.withOpacity(t.isDark ? 1.0 : 0.75),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: t.border),
              boxShadow: [
                BoxShadow(
                  color: t.textPrimary.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.sageGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.lock_outline_rounded,
                      color: AppColors.sageGreen, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Change Password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Update your account password',
                        style: TextStyle(
                            fontSize: 13, color: t.textMuted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: t.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionInfo(AppThemeTokens t) {
    return FutureBuilder(
      future: _getSubscriptionInfo(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        
        if (snapshot.hasData) {
          final sub = snapshot.data!;
          final isPro = sub['plan'] == 'pro';
          final isHospital = sub['plan'] == 'hospital' || sub['plan'] == 'hospital_pro';
          final isFreemium = sub['plan'] == 'freemium';
          
          final accentColor = isPro || isHospital ? AppColors.sageGreen : Colors.orange;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: accentColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isPro || isHospital ? Icons.star_rounded : Icons.info_outline_rounded,
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isPro ? 'Pro Plan Active' : (isHospital ? 'Hospital Plan Active' : 'Freemium Plan'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (sub['prediction_limit'] != null && !isHospital)
                  Text(
                    'Predictions used this month: ${sub['monthly_predictions_used']}/${sub['prediction_limit']}',
                    style: TextStyle(fontSize: 14, color: t.textPrimary),
                  ),
                if (sub['is_hospital_linked'] == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '🔗 Linked via ${sub['hospital_admin']}',
                      style: TextStyle(fontSize: 13, color: AppColors.sageGreen, fontWeight: FontWeight.w500),
                    ),
                  ),
                
                if (isFreemium || isPro)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PricingScreen()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accentColor,
                          side: BorderSide(color: accentColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(isFreemium ? 'Upgrade to Pro' : 'Upgrade to Hospital Plan', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
  
  Future<Map<String, dynamic>> _getSubscriptionInfo() async {
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        return await ApiService.getMySubscription(token);
      }
    } catch (e) {
      debugPrint('Error getting subscription: $e');
    }
    return {'plan': 'freemium', 'monthly_predictions_used': 0, 'prediction_limit': 15};
  }

  Widget _buildLogoutButton(double bottomPadding) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding + 16),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: OutlinedButton(
          onPressed: _logout,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade400,
            side: BorderSide(color: Colors.red.shade300, width: 1.2),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('Log Out',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    required AppThemeTokens t,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AppLabel(label, t),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: enabled,
          style: TextStyle(color: t.textPrimary),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.sageGreen, size: 20),
            filled: true,
            fillColor: t.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: t.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.sageGreen, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(
    TextEditingController controller,
    String label,
    bool obscure,
    VoidCallback toggleObscure,
    AppThemeTokens t,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AppLabel(label, t),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: TextStyle(color: t.textPrimary),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                color: AppColors.sageGreen),
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: t.textMuted,
              ),
              onPressed: toggleObscure,
            ),
            filled: true,
            fillColor: t.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: t.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.sageGreen, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _AppLabel extends StatelessWidget {
  final String text;
  final AppThemeTokens t;
  const _AppLabel(this.text, this.t);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: t.textMuted,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final AppThemeTokens t;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.sageGreen),
          const SizedBox(width: 16),
          SizedBox(
            width: 100, // Adjusted width slightly to give values more breathing room
            child: Text(
              label,
              style: TextStyle(
                color: t.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}