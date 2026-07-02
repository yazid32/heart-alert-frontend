// lib/screens/assistant_home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/token_service.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../utils/responsive_utils.dart';
import '../config/app_config.dart';
import 'assistant_patients_screen.dart';
import 'assistant_history_screen.dart';
import 'profile_screen.dart';

class AssistantHomeScreen extends StatefulWidget {
  const AssistantHomeScreen({super.key});

  @override
  State<AssistantHomeScreen> createState() => _AssistantHomeScreenState();
}

class _AssistantHomeScreenState extends State<AssistantHomeScreen> {
  int _currentIndex = 0;
  User? _currentUser;
  Map<String, dynamic>? _assignedDoctor;
  String? _profilePicture;
  bool _isLoading = true;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void setCurrentIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = await TokenService.getUser();
      final token = await TokenService.getToken();

      if (token != null && _currentUser != null) {
        try {
          final doctor = await ApiService.getAssignedDoctor(token);
          final userInfo = await ApiService.getMe(token);
          setState(() {
            _assignedDoctor = doctor;
            _profilePicture = userInfo['profile_picture'];
          });
        } catch (e) {
          print('Error loading assigned doctor: $e');
          setState(() {
            _assignedDoctor = {
              'first_name': 'Not',
              'last_name': 'Assigned',
              'specialty': 'No doctor assigned yet',
              'hospital': 'Contact your administrator',
            };
          });
        }
      }
      setState(() => _isLoading = false);
      _initPages();
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
        _assignedDoctor = {
          'first_name': 'Not',
          'last_name': 'Assigned',
          'specialty': 'No doctor assigned yet',
          'hospital': 'Contact your administrator',
        };
      });
      _initPages();
    }
  }

  void _initPages() {
    _pages = [
      _HomeTab(
        assistantName: _currentUser?.fullName ?? 'Assistant',
        doctorName: _assignedDoctor != null
            ? 'Dr. ${_assignedDoctor!['first_name']} ${_assignedDoctor!['last_name']}'
            : 'Not Assigned',
        doctorSpecialty: _assignedDoctor?['specialty'] ?? 'No doctor assigned',
        doctorHospital: _assignedDoctor?['hospital'] ?? 'Contact administrator',
        profilePicture: _profilePicture,
        onNavigate: setCurrentIndex,
      ),
      const AssistantPatientsScreen(),
      const AssistantHistoryScreen(),
    ];
  }

  void _goToProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final isWeb = MediaQuery.of(context).size.width > 600;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: t.bg,
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.sageGreen),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        title: Text(
          isWeb ? 'Assistant Dashboard' : 'Assistant',
          style: TextStyle(
            color: t.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          // Theme Toggle
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: t.border.withOpacity(0.5)),
            ),
            child: IconButton(
              icon: Icon(
                themeProvider.getThemeModeIcon(),
                color: t.textPrimary.withOpacity(0.6),
                size: 20,
              ),
              onPressed: () => themeProvider.toggleTheme(),
              tooltip: 'Theme: ${themeProvider.getThemeModeLabel()}',
              style: IconButton.styleFrom(padding: const EdgeInsets.all(10)),
            ),
          ),
          // Profile
          GestureDetector(
            onTap: () => _goToProfile(context),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.sageGreen.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: _profilePicture != null
                    ? CachedNetworkImage(
                        imageUrl: '${AppConfig.baseUrl}$_profilePicture',
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.sageGreen.withOpacity(0.1),
                          child: const Icon(Icons.person_rounded, color: AppColors.sageGreen),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.sageGreen.withOpacity(0.1),
                          child: const Icon(Icons.person_rounded, color: AppColors.sageGreen),
                        ),
                      )
                    : Container(
                        color: AppColors.sageGreen.withOpacity(0.1),
                        child: const Icon(Icons.person_rounded, color: AppColors.sageGreen),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: isWeb
          ? null
          : BottomNavigationBar(
              currentIndex: _currentIndex,
              backgroundColor: t.bg,
              selectedItemColor: AppColors.sageGreen,
              unselectedItemColor: t.textMuted,
              onTap: setCurrentIndex,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_rounded),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.assignment_ind_rounded),
                  label: 'Patients',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history_toggle_off_rounded),
                  label: 'History',
                ),
              ],
            ),
    );
  }
}

// ─── Home Tab ─────────────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  final String assistantName;
  final String doctorName;
  final String doctorSpecialty;
  final String doctorHospital;
  final String? profilePicture;
  final ValueChanged<int> onNavigate;

  const _HomeTab({
    required this.assistantName,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.doctorHospital,
    this.profilePicture,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(r.wp(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome
          Text(
            'Welcome Back,',
            style: TextStyle(
              color: t.textMuted,
              fontSize: r.fs(13),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            assistantName,
            style: TextStyle(
              color: t.textPrimary,
              fontSize: r.fs(22),
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: r.sp(24)),
          
          // Assigned Doctor Card
          Text(
            'Assigned Clinical Supervisor',
            style: TextStyle(
              color: t.textPrimary,
              fontSize: r.fs(14),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: r.sp(10)),
          Container(
            padding: EdgeInsets.all(r.sp(16)),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(r.sp(18)),
              border: Border.all(color: t.border.withOpacity(0.7)),
              boxShadow: [
                BoxShadow(
                  color: t.textPrimary.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: r.wp(42),
                      height: r.wp(42),
                      decoration: BoxDecoration(
                        color: AppColors.sageGreen.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.healing_rounded,
                          color: AppColors.sageGreen,
                          size: r.wp(20),
                        ),
                      ),
                    ),
                    SizedBox(width: r.wp(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doctorName,
                            style: TextStyle(
                              color: t.textPrimary,
                              fontSize: r.fs(15),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            doctorSpecialty,
                            style: TextStyle(
                              color: t.textMuted,
                              fontSize: r.fs(12),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Icon(Icons.apartment_rounded, size: r.sp(16), color: t.textMuted),
                    SizedBox(width: r.wp(8)),
                    Expanded(
                      child: Text(
                        doctorHospital,
                        style: TextStyle(
                          color: t.textPrimary.withOpacity(0.8),
                          fontSize: r.fs(12),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: r.sp(24)),
          
          // Quick Actions
          Text(
            'Quick Actions',
            style: TextStyle(
              color: t.textPrimary,
              fontSize: r.fs(14),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: r.sp(10)),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.people_alt_rounded,
                  label: 'Manage Patients',
                  onTap: () => onNavigate(1),
                  r: r,
                  t: t,
                ),
              ),
              SizedBox(width: r.wp(12)),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.analytics_rounded,
                  label: 'Past Diagnostics',
                  onTap: () => onNavigate(2),
                  r: r,
                  t: t,
                ),
              ),
            ],
          ),
          SizedBox(height: r.sp(28)),
          
          // Permissions Banner
          Container(
            padding: EdgeInsets.all(r.sp(14)),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.06),
              borderRadius: BorderRadius.circular(r.sp(14)),
              border: Border.all(color: Colors.amber.shade200.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: r.sp(18),
                      color: Colors.amber.shade700,
                    ),
                    SizedBox(width: r.wp(6)),
                    Text(
                      'Role Scoping & Permissions',
                      style: TextStyle(
                        color: Colors.amber.shade800,
                        fontSize: r.fs(12),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.sp(8)),
                Text(
                  '• Review and update patient directories\n• Query comprehensive execution files\n• Transmit diagnostic updates to central system\n• Execution actions are logged continuously',
                  style: TextStyle(
                    color: t.textPrimary.withOpacity(0.7),
                    fontSize: r.fs(12),
                    height: 1.5,
                    fontWeight: FontWeight.w500,
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

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Responsive r;
  final AppThemeTokens t;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.r,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(r.sp(16)),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(r.sp(16)),
          border: Border.all(color: t.border.withOpacity(0.7)),
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
            Container(
              padding: EdgeInsets.all(r.sp(8)),
              decoration: BoxDecoration(
                color: AppColors.sageGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(r.sp(10)),
              ),
              child: Icon(icon, color: AppColors.sageGreen, size: r.sp(20)),
            ),
            SizedBox(height: r.sp(16)),
            Text(
              label,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: r.fs(13),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}