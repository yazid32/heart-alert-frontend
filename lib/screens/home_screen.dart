import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../services/token_service.dart';
import '../services/api_service.dart';
import '../services/pdf_service.dart';
import '../utils/responsive_utils.dart';
import 'history_screen.dart';
import 'prediction_screen.dart';
import 'chatbot_screen.dart';
import 'profile_screen.dart';
import 'patient_screen.dart';
import '../config/app_config.dart';
import 'pricing_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<dynamic> _recentPredictions = [];
  String? _doctorName;
  String? _doctorSpecialty;
  String? _doctorHospital;
  String? _profilePicture;

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  void setCurrentIndex(int index) => setState(() => _currentIndex = index);

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        final doctorInfo = await ApiService.getMe(token);
        setState(() {
          _doctorName = 'Dr. ${doctorInfo['first_name']} ${doctorInfo['last_name']}';
          _doctorSpecialty = doctorInfo['specialty'] ?? 'Cardiologist';
          _doctorHospital = doctorInfo['hospital'] ?? 'City General Hospital';
          _profilePicture = doctorInfo['profile_picture'];
        });

        final history = await ApiService.getHistory(token);
        final predictions = history['predictions'] ?? [];
        final today = DateTime.now();
        bool _isToday(String? rawDate) {
          if (rawDate == null) return false;
          try {
            final d = DateTime.parse(rawDate);
            return d.year == today.year && d.month == today.month && d.day == today.day;
          } catch (_) {
            return false;
          }
        }

        final patientsResponse = await ApiService.getPatients(token: token);
        final totalPatients = patientsResponse['total'] ?? patientsResponse.length ?? 0;

        // Try to scope "new patients" to today too — fall back to 0 if the
        // patients endpoint doesn't expose a creation date in this shape.
        int todayNewPatients = 0;
        try {
          final patientList = (patientsResponse['patients'] ?? patientsResponse['results'] ?? patientsResponse) as List;
          todayNewPatients = patientList.where((p) => _isToday(p['created_at'] ?? p['date_added'])).length;
        } catch (_) {
          todayNewPatients = 0;
        }

        final todayPredictions = predictions.where((p) => _isToday(p['created_at'])).toList();
        final todayHighRisk = todayPredictions.where((p) => p['risk_category'] == 'high').length;

        setState(() {
          _stats = {
            'total_predictions': predictions.length,
            'total_patients': totalPatients,
            // Today-scoped figures shown on the home banner's floating cards.
            'today_predictions': todayPredictions.length,
            'today_new_patients': todayNewPatients,
            'today_high_risk': todayHighRisk,
            // kept for backward compatibility with any other callers
            'high_risk_count': predictions.where((p) => p['risk_category'] == 'high').length,
            'today_count': todayPredictions.length,
          };
          _recentPredictions = predictions.take(3).toList();
          _isLoading = false;
        });
        _initPages();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _initPages();
    }
  }

  void _initPages() {
    _pages
      ..clear()
      ..addAll([
        _HomeTab(
          isLoading: _isLoading,
          stats: _stats,
          recentPredictions: _recentPredictions,
          doctorName: _doctorName ?? 'Doctor',
          doctorSpecialty: _doctorSpecialty ?? 'Cardiologist',
          doctorHospital: _doctorHospital ?? 'City General Hospital',
          profilePicture: _profilePicture,
          onRefresh: _fetchDashboardData,
        ),
        const PatientsScreen(),
        const PredictionScreen(),
        const HistoryScreen(),
        const ChatbotScreen(),
      ]);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);
    
    final isDesktop = MediaQuery.of(context).size.width >= 850;

    if (_pages.isEmpty) {
      return Scaffold(
        backgroundColor: t.bg,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: const AlwaysStoppedAnimation(AppColors.sageGreen),
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: isDesktop
            ? Row(
                children: [
                  _DesktopSidebar(
                    currentIndex: _currentIndex,
                    onTap: setCurrentIndex,
                    r: r,
                    doctorName: _doctorName ?? 'Doctor',
                    profilePicture: _profilePicture,
                  ),
                  Expanded(child: IndexedStack(index: _currentIndex, children: _pages)),
                ],
              )
            : IndexedStack(index: _currentIndex, children: _pages),
      ),
      bottomNavigationBar: isDesktop
          ? null
          : _MobileNavBar(
              currentIndex: _currentIndex,
              onTap: setCurrentIndex,
              r: r,
              t: t,
            ),
    );
  }
}

// ─── Mobile Nav Bar ──────────────────────────────────────────────────────────
class _MobileNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Responsive r;
  final AppThemeTokens t;

  const _MobileNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.r,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(top: BorderSide(color: t.border.withOpacity(0.3))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(t.isDark ? 0.2 : 0.05),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(r.wp(12), r.sp(10), r.wp(12), r.sp(10)),
          child: Container(
            height: r.sp(64),
            decoration: BoxDecoration(
              color: t.isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(r.sp(20)),
              border: Border.all(color: t.border.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                _NavItem(icon: Icons.home_rounded, label: 'Home', selected: currentIndex == 0, onTap: () => onTap(0), r: r),
                _NavItem(icon: Icons.people_outline_rounded, label: 'Patients', selected: currentIndex == 1, onTap: () => onTap(1), r: r),
                _CenterPredictButton(onTap: () => onTap(2), r: r),
                _NavItem(icon: Icons.history_rounded, label: 'History', selected: currentIndex == 3, onTap: () => onTap(3), r: r),
                _NavItem(icon: Icons.chat_bubble_outline_rounded, label: 'Chat', selected: currentIndex == 4, onTap: () => onTap(4), r: r),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Desktop Sidebar ─────────────────────────────────────────────────────────
class _DesktopSidebar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final Responsive r;
  final String doctorName;
  final String? profilePicture;

  // Index 5 = Profile (virtual, not in IndexedStack — navigates via push)
  static const int profileIndex = 5;

  const _DesktopSidebar({
    required this.currentIndex,
    required this.onTap,
    required this.r,
    required this.doctorName,
    this.profilePicture,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeTokens.of(context);
    final profileImageUrl = (profilePicture != null && profilePicture!.isNotEmpty)
        ? '${AppConfig.baseUrl}$profilePicture'
        : null;

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(right: BorderSide(color: t.border.withOpacity(0.4))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 28),
          // Brand
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.sageGreen, AppColors.sageGreen.withOpacity(0.75)],
                    ),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(color: AppColors.sageGreen.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Image.asset(
                      'assets/icon/icon.png',
                      errorBuilder: (_, __, ___) => const Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Heart Alert',
                  style: TextStyle(color: t.textPrimary, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),

          // Nav items
          _SidebarItem(icon: Icons.dashboard_rounded, label: 'Dashboard', selected: currentIndex == 0, onTap: () => onTap(0)),
          _SidebarItem(icon: Icons.people_outline_rounded, label: 'Patients', selected: currentIndex == 1, onTap: () => onTap(1)),
          _SidebarItem(icon: Icons.history_rounded, label: 'History', selected: currentIndex == 3, onTap: () => onTap(3)),
          _SidebarItem(icon: Icons.chat_bubble_outline_rounded, label: 'AI Chatbot', selected: currentIndex == 4, onTap: () => onTap(4)),

          const Spacer(),

          // New Prediction CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => onTap(2),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Prediction', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sageGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                ),
              ),
            ),
          ),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(height: 1, color: t.border.withOpacity(0.5)),
          ),
          const SizedBox(height: 12),

          // Profile item
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.sageGreen.withOpacity(0.35), width: 1.5),
                      ),
                      child: ClipOval(
                        child: profileImageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: profileImageUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: AppColors.sageGreen.withOpacity(0.1),
                                  child: const Icon(Icons.person_rounded, size: 16, color: AppColors.sageGreen),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: AppColors.sageGreen.withOpacity(0.1),
                                  child: const Icon(Icons.person_rounded, size: 16, color: AppColors.sageGreen),
                                ),
                              )
                            : Container(
                                color: AppColors.sageGreen.withOpacity(0.1),
                                child: const Icon(Icons.person_rounded, size: 16, color: AppColors.sageGreen),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doctorName,
                            style: TextStyle(
                              color: t.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'View profile',
                            style: TextStyle(color: t.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 16, color: t.textMuted),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeTokens.of(context);
    final color = selected ? AppColors.sageGreen : t.textPrimary.withOpacity(0.45);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? AppColors.sageGreen.withOpacity(0.09) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (selected) ...[
                const Spacer(),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.sageGreen,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Home Tab ─────────────────────────────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  final bool isLoading;
  final Map<String, dynamic> stats;
  final List<dynamic> recentPredictions;
  final String doctorName;
  final String doctorSpecialty;
  final String doctorHospital;
  final String? profilePicture;
  final VoidCallback onRefresh;

  const _HomeTab({
    required this.isLoading,
    required this.stats,
    required this.recentPredictions,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.doctorHospital,
    required this.profilePicture,
    required this.onRefresh,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  String _currentSubscriptionPlan = 'freemium';
  bool _loadingPlan = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionPlan();
  }

  Future<void> _loadSubscriptionPlan() async {
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        final sub = await ApiService.getMySubscription(token);
        setState(() { _currentSubscriptionPlan = sub['plan']; _loadingPlan = false; });
      } else {
        setState(() => _loadingPlan = false);
      }
    } catch (e) {
      setState(() => _loadingPlan = false);
    }
  }

  String _formatDate(String dateTimeStr) {
    try {
      final date = DateTime.parse(dateTimeStr);
      final difference = DateTime.now().difference(date);
      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateTimeStr;
    }
  }

  // ── Status Timeline ─────────────────────────────────────────────────────
  Widget _buildStatusTimeline(bool hasPending, bool hasAssistant, BuildContext context, bool isDesktop) {
    final r = Responsive.of(context);
    final steps = [
      {'label': 'Requested', 'completed': hasPending || hasAssistant, 'active': hasPending},
      {'label': 'Review', 'completed': hasAssistant, 'active': false},
      {'label': 'Approved', 'completed': hasAssistant, 'active': false},
    ];

    return Container(
      margin: EdgeInsets.only(top: isDesktop ? 14 : r.sp(14)),
      padding: EdgeInsets.symmetric(vertical: isDesktop ? 14 : r.sp(14), horizontal: isDesktop ? 16 : r.sp(16)),
      decoration: BoxDecoration(
        color: AppColors.sageGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(isDesktop ? 14 : r.sp(14)),
        border: Border.all(color: AppColors.sageGreen.withOpacity(0.1)),
      ),
      child: Row(
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isLast = index == steps.length - 1;
          final isCompleted = step['completed'] == true;
          final isActive = step['active'] == true;
          final dotColor = isCompleted
              ? AppColors.sageGreen
              : isActive
                  ? const Color(0xFFE65100)
                  : Colors.grey.shade300;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor,
                          boxShadow: (isCompleted || isActive)
                              ? [BoxShadow(color: dotColor.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 2))]
                              : [],
                        ),
                        child: Icon(
                          isCompleted ? Icons.check_rounded : (isActive ? Icons.timelapse_rounded : Icons.radio_button_unchecked_rounded),
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        step['label'] as String,
                        style: TextStyle(
                          fontSize: isDesktop ? 11 : r.fs(10),
                          color: isCompleted ? AppColors.sageGreen : Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: isCompleted ? AppColors.sageGreen : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _cancelRequest(BuildContext context, int requestId) async {
    final t = AppThemeTokens.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 22),
            const SizedBox(width: 10),
            Text('Cancel Request', style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel this assistant request?',
          style: TextStyle(color: t.textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep it', style: TextStyle(color: t.textMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancel Request', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        await ApiService.cancelAssistantRequest(token: token, requestId: requestId);
        if (context.mounted) {
          widget.onRefresh();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Request cancelled'),
            ]),
            backgroundColor: AppColors.sageGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  String _getPatientName(Map<String, dynamic> p) {
    if (p['patient_name'] != null && p['patient_name'].toString().isNotEmpty) return p['patient_name'];
    if (p['patient_id'] != null) return 'Patient ID: ${p['patient_id']}';
    return 'Patient ${p['id']}';
  }

  Future<void> _exportPrediction(Map<String, dynamic> prediction) async {
    try {
      await PdfService.exportPrediction(prediction);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _getAssistantStatus() async {
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        final assistant = await ApiService.getMyAssistant(token);
        if (assistant['has_assistant'] == true) {
          return {'has_assistant': true, 'has_pending': false, 'status': 'approved', 'request_id': null};
        }
        final pendingResponse = await ApiService.getDoctorPendingRequest(token);
        final hasPending = pendingResponse['has_pending'] == true;
        final requestId = pendingResponse['request_id'];
        if (hasPending) {
          return {'has_assistant': false, 'has_pending': true, 'status': 'pending', 'request_id': requestId};
        }
      }
    } catch (e) {
      print('Error checking assistant status: $e');
    }
    return {'has_assistant': false, 'has_pending': false, 'status': 'none', 'request_id': null};
  }

  Future<void> _requestAssistant(BuildContext context) async {
    final isPro = _currentSubscriptionPlan == 'pro' || _currentSubscriptionPlan == 'hospital_pro';
    if (!isPro) {
      _showUpgradeRequiredDialog(context);
      return;
    }

    try {
      final token = await TokenService.getToken();
      if (token != null) {
        final assistant = await ApiService.getMyAssistant(token);
        if (assistant['has_assistant'] == true) {
          if (context.mounted) _showSnack(context, 'You already have an assistant assigned.', Colors.orange);
          return;
        }
        final pendingResponse = await ApiService.getDoctorPendingRequest(token);
        if (pendingResponse['has_pending'] == true) {
          if (context.mounted) _showSnack(context, 'You already have a pending request.', Colors.orange);
          return;
        }
      }
    } catch (e) {
      print('Error checking status: $e');
    }

    final t = AppThemeTokens.of(context);
    final r = Responsive.of(context);
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) => Dialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.sp(24))),
        child: Container(
          constraints: BoxConstraints(maxWidth: r.wp(460)),
          padding: EdgeInsets.all(r.sp(24)),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(r.sp(10)),
                      decoration: BoxDecoration(
                        color: AppColors.sageGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(r.sp(12)),
                      ),
                      child: Icon(Icons.person_add_rounded, color: AppColors.sageGreen, size: r.sp(22)),
                    ),
                    SizedBox(width: r.sp(14)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Request an Assistant',
                              style: TextStyle(fontSize: r.fs(17), fontWeight: FontWeight.w800, color: t.textPrimary, letterSpacing: -0.3)),
                          Text('Admin will review your request.',
                              style: TextStyle(fontSize: r.fs(12), color: t.textMuted)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: t.textMuted, size: r.sp(20)),
                      style: IconButton.styleFrom(
                        backgroundColor: t.border.withOpacity(0.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.all(r.sp(4)),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.sp(20)),

                _DialogTextField(ctrl: nameCtrl, label: 'Assistant Full Name *', icon: Icons.person_outline_rounded, r: r, t: t),
                SizedBox(height: r.sp(14)),
                _DialogTextField(ctrl: emailCtrl, label: 'Assistant Email *', icon: Icons.email_outlined, r: r, t: t, keyboardType: TextInputType.emailAddress),
                SizedBox(height: r.sp(14)),
                _DialogTextField(ctrl: phoneCtrl, label: 'Phone (optional)', icon: Icons.phone_outlined, r: r, t: t, keyboardType: TextInputType.phone),
                SizedBox(height: r.sp(14)),
                _DialogTextField(ctrl: notesCtrl, label: 'Notes (optional)', icon: Icons.notes_rounded, r: r, t: t, maxLines: 3),
                SizedBox(height: r.sp(20)),

                SizedBox(
                  width: double.infinity,
                  height: r.sp(50),
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty) {
                        _showSnack(context, 'Please fill in name and email', Colors.orange);
                        return;
                      }
                      Navigator.pop(context);
                      try {
                        final token = await TokenService.getToken();
                        if (token != null) {
                          await ApiService.requestAssistant(
                            token: token,
                            assistantEmail: emailCtrl.text.trim(),
                            assistantName: nameCtrl.text.trim(),
                            assistantPhone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                            notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                          );
                          if (context.mounted) {
                            widget.onRefresh();
                            _showSnack(context, 'Request submitted! Admin will review it.', AppColors.sageGreen);
                          }
                        }
                      } catch (e) {
                        if (context.mounted) _showSnack(context, 'Error: $e', Colors.red);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sageGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.sp(12))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded, size: r.sp(16)),
                        SizedBox(width: r.sp(8)),
                        Text('Submit Request', style: TextStyle(fontSize: r.fs(14), fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSnack(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showUpgradeRequiredDialog(BuildContext context) {
    final t = AppThemeTokens.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: AppColors.sageGreen, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Pro Feature', style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ],
        ),
        content: Text(
          'Requesting a dedicated assistant is available on the Pro plan. Upgrade to get help managing your patients.',
          style: TextStyle(color: t.textMuted, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Not now', style: TextStyle(color: t.textMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PricingScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sageGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Upgrade to Pro', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _goToProfile(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  // ── Assistant Section ───────────────────────────────────────────────────
  Widget _buildAssistantSection(BuildContext context, AppThemeTokens t, Responsive r, bool isDesktop, bool isPro) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getAssistantStatus(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.all(r.sp(18)),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(r.sp(16)),
              border: Border.all(color: t.border.withOpacity(0.6)),
            ),
            child: Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sageGreen),
              ),
            ),
          );
        }

        final status = snapshot.data!;
        final hasAssistant = status['has_assistant'] == true;
        final hasPending = status['has_pending'] == true;
        final requestId = status['request_id'];

        if (hasAssistant) {
          return Column(
            children: [
              _AssistantBanner(
                icon: Icons.verified_user_rounded,
                color: AppColors.sageGreen,
                title: 'Assistant Assigned',
                subtitle: 'Your assistant is active and helping manage your patients.',
              ),
              _buildStatusTimeline(false, true, context, isDesktop),
            ],
          );
        }

        if (hasPending) {
          return Column(
            children: [
              _AssistantBanner(
                icon: Icons.hourglass_top_rounded,
                color: Color(0xFFE65100),
                title: 'Request Pending',
                subtitle: 'Admin is reviewing your assistant request.',
              ),
              _buildStatusTimeline(true, false, context, isDesktop),
              SizedBox(height: r.sp(10)),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: requestId == null ? null : () => _cancelRequest(context, requestId as int),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                    side: BorderSide(color: Colors.red.shade200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.sp(12))),
                    padding: EdgeInsets.symmetric(vertical: r.sp(12)),
                  ),
                  child: const Text('Cancel Request', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          );
        }

        // No assistant, no pending request — offer to request one, gated by plan
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(r.sp(18)),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(r.sp(16)),
            border: Border.all(color: t.border.withOpacity(0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(r.sp(10)),
                    decoration: BoxDecoration(
                      color: AppColors.sageGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(r.sp(12)),
                    ),
                    child: Icon(Icons.person_add_alt_1_rounded, color: AppColors.sageGreen, size: r.sp(20)),
                  ),
                  SizedBox(width: r.wp(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Need help managing patients?',
                            style: TextStyle(fontSize: r.fs(14), fontWeight: FontWeight.w700, color: t.textPrimary)),
                        SizedBox(height: r.sp(2)),
                        Text(
                          isPro
                              ? 'Request an assistant to help with your workflow.'
                              : 'Upgrade to Pro to request a dedicated assistant.',
                          style: TextStyle(fontSize: r.fs(12), color: t.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: r.sp(16)),
              SizedBox(
                width: double.infinity,
                height: r.sp(46),
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (isPro) {
                      _requestAssistant(context);
                    } else {
                      _showUpgradeRequiredDialog(context);
                    }
                  },
                  icon: Icon(isPro ? Icons.person_add_rounded : Icons.lock_outline_rounded, size: r.sp(16)),
                  label: Text(
                    isPro ? 'Request an Assistant' : 'Pro Feature — Upgrade to Unlock',
                    style: TextStyle(fontSize: r.fs(13.5), fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPro ? AppColors.sageGreen : t.border.withOpacity(0.5),
                    foregroundColor: isPro ? Colors.white : t.textMuted,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.sp(12))),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Main build ──────────────────────────────────────────────────────────
@override
Widget build(BuildContext context) {
  final r = Responsive.of(context);
  final t = AppThemeTokens.of(context);
  final themeProvider = context.watch<ThemeProvider>();
  
  String? profileImageUrl;
  if (widget.profilePicture != null && widget.profilePicture!.isNotEmpty) {
    profileImageUrl = '${AppConfig.baseUrl}${widget.profilePicture}';
  }

  final isPro = _currentSubscriptionPlan == 'pro' || _currentSubscriptionPlan == 'hospital_pro';
  final isDesktop = MediaQuery.of(context).size.width >= 850;

  return RefreshIndicator(
    onRefresh: () async => widget.onRefresh(),
    color: AppColors.sageGreen,
    backgroundColor: t.surface,
    child: SingleChildScrollView(
      key: const ValueKey('home-tab'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 32.0 : r.hp,
        isDesktop ? 24.0 : r.sp(24),
        isDesktop ? 32.0 : r.hp,
        isDesktop ? 40.0 : r.sp(120),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Banner ───────────────────────────────────
              _buildWarmCardBanner(t, r, profileImageUrl, isDesktop, themeProvider),
              SizedBox(height: isDesktop ? 20 : r.sp(18)),

              // ── Stats row (simple, no overlap) ────────────
              _SectionTitle("Today's Overview", r, isDesktop: isDesktop),
              SizedBox(height: isDesktop ? 14 : r.sp(14)),
              widget.isLoading
                  ? _StatsLoadingSkeleton(isDesktop: false, r: r)
                  : Row(
                      children: [
                        Expanded(
                          child: _FloatingStatCard(
                            label: 'New Patients',
                            value: '${widget.stats['today_new_patients'] ?? 0}',
                            icon: Icons.people_outline_rounded,
                            color: AppColors.sageGreen,
                            r: r,
                            isDesktop: isDesktop,
                          ),
                        ),
                        SizedBox(width: isDesktop ? 12 : r.wp(10)),
                        Expanded(
                          child: _FloatingStatCard(
                            label: 'High Risk',
                            value: '${widget.stats['today_high_risk'] ?? 0}',
                            icon: Icons.warning_amber_rounded,
                            color: const Color(0xFFC97C5D),
                            r: r,
                            isDesktop: isDesktop,
                          ),
                        ),
                        SizedBox(width: isDesktop ? 12 : r.wp(10)),
                        Expanded(
                          child: _FloatingStatCard(
                            label: 'Predictions',
                            value: '${widget.stats['today_predictions'] ?? 0}',
                            icon: Icons.monitor_heart_outlined,
                            color: Colors.blue.shade400,
                            r: r,
                            isDesktop: isDesktop,
                          ),
                        ),
                      ],
                    ),
              SizedBox(height: isDesktop ? 28 : r.sp(28)),

              // ── Assistant ────────────────────────────────
              _SectionTitle('Assistant', r, isDesktop: isDesktop),
              SizedBox(height: isDesktop ? 14 : r.sp(14)),
              _loadingPlan
                  ? Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(r.sp(18)),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(r.sp(16)),
                        border: Border.all(color: t.border.withOpacity(0.6)),
                      ),
                      child: Center(
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sageGreen),
                        ),
                      ),
                    )
                  : _buildAssistantSection(context, t, r, isDesktop, isPro),
              SizedBox(height: isDesktop ? 28 : r.sp(28)),

              _buildRecentCasesLayout(t, r, isDesktop),
            ],
          ),
        ),
      ),
    ),
  );
}

// ── Warm Card Banner ────────────────────────────────────────────────────
Widget _buildWarmCardBanner(
  AppThemeTokens t,
  Responsive r,
  String? profileImageUrl,
  bool isDesktop,
  ThemeProvider themeProvider,
) {
  return Container(
    width: double.infinity,
    padding: EdgeInsets.all(isDesktop ? 24 : r.sp(20)),
    decoration: BoxDecoration(
      gradient: t.primaryGradient,
      borderRadius: BorderRadius.circular(isDesktop ? 24 : r.sp(22)),
      boxShadow: [
        BoxShadow(
          color: AppColors.sageGreen.withOpacity(0.30),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top row: brand mark + theme toggle
        Row(
          children: [
            Container(
              width: isDesktop ? 32 : r.wp(28),
              height: isDesktop ? 32 : r.wp(28),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(isDesktop ? 10 : r.sp(9)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Image.asset(
                  'assets/icon/icon.png',
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.favorite_rounded, color: Colors.white, size: 16),
                ),
              ),
            ),
            const Spacer(),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(11),
              ),
              child: IconButton(
                icon: Icon(
                  themeProvider.getThemeModeIcon(),
                  color: Colors.white,
                  size: 19,
                ),
                onPressed: () => themeProvider.toggleTheme(),
                tooltip: 'Theme: ${themeProvider.getThemeModeLabel()}',
                style: IconButton.styleFrom(padding: const EdgeInsets.all(8)),
              ),
            ),
          ],
        ),
        SizedBox(height: isDesktop ? 20 : r.sp(18)),
        // Greeting + name + avatar
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.78),
                          fontSize: isDesktop ? 14 : r.fs(13),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.white.withOpacity(0.6), blurRadius: 6),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.doctorName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isDesktop ? 30 : r.fs(26),
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.medical_services_outlined,
                        size: isDesktop ? 14 : r.fs(13),
                        color: Colors.white.withOpacity(0.85),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${widget.doctorSpecialty} · ${widget.doctorHospital}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: isDesktop ? 13 : r.fs(12.5),
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: isDesktop ? 18 : r.wp(14)),
            // Avatar on the right
            GestureDetector(
              onTap: () => _goToProfile(context),
              child: Container(
                width: isDesktop ? 64 : r.wp(60),
                height: isDesktop ? 64 : r.wp(60),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.55), width: 2.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: ClipOval(
                    child: profileImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: profileImageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: Colors.white.withOpacity(0.2),
                              child: const Icon(Icons.person_rounded, size: 28, color: Colors.white),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.white.withOpacity(0.2),
                              child: const Icon(Icons.person_rounded, size: 28, color: Colors.white),
                            ),
                          )
                        : Container(
                            color: Colors.white.withOpacity(0.2),
                            child: const Icon(Icons.person_rounded, size: 28, color: Colors.white),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
 
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  // ── Recent Cases ────────────────────────────────────────────────────────
  Widget _buildRecentCasesLayout(AppThemeTokens t, Responsive r, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionTitle('Recent Cases', r, isDesktop: isDesktop),
            if (!widget.isLoading && widget.recentPredictions.isNotEmpty)
              TextButton(
                onPressed: () => context.findAncestorStateOfType<_HomeScreenState>()?.setCurrentIndex(3),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.sageGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('See all', style: TextStyle(fontSize: isDesktop ? 13 : r.fs(13), fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 14),
                  ],
                ),
              ),
          ],
        ),
        SizedBox(height: isDesktop ? 14 : r.sp(14)),
        if (widget.isLoading)
          _CasesLoadingSkeleton(r: r, t: t)
        else if (widget.recentPredictions.isEmpty)
          _EmptyCasesState(r: r, t: t, isDesktop: isDesktop, onNewPrediction: () {
            context.findAncestorStateOfType<_HomeScreenState>()?.setCurrentIndex(2);
          })
        else
          ...widget.recentPredictions.map((p) => Padding(
                padding: EdgeInsets.only(bottom: r.sp(10)),
                child: _PatientPreviewCard(
                  prediction: p,
                  patientName: _getPatientName(p),
                  age: '${p['age']}',
                  status: p['risk_category'] == 'high'
                      ? 'High Risk'
                      : p['risk_category'] == 'moderate'
                          ? 'Moderate Risk'
                          : 'Low Risk',
                  time: _formatDate(p['created_at']),
                  onExport: () => _exportPrediction(p),
                  r: r,
                  isDesktop: isDesktop,
                ),
              )),
      ],
    );
  }
}

// ─── Assistant Banner ─────────────────────────────────────────────────────────
class _AssistantBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _AssistantBanner({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
                Text(subtitle, style: TextStyle(color: color.withOpacity(0.75), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dialog TextField ─────────────────────────────────────────────────────────
class _DialogTextField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final Responsive r;
  final AppThemeTokens t;
  final TextInputType keyboardType;
  final int maxLines;

  const _DialogTextField({
    required this.ctrl,
    required this.label,
    required this.icon,
    required this.r,
    required this.t,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: t.textPrimary, fontSize: r.fs(14)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: t.textMuted, fontSize: r.fs(13)),
        prefixIcon: Icon(icon, color: AppColors.sageGreen, size: r.sp(18)),
        filled: true,
        fillColor: t.isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(r.sp(12)), borderSide: BorderSide(color: t.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(r.sp(12)), borderSide: BorderSide(color: t.border.withOpacity(0.6))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(r.sp(12)), borderSide: const BorderSide(color: AppColors.sageGreen, width: 1.5)),
        contentPadding: EdgeInsets.symmetric(horizontal: r.wp(16), vertical: r.sp(13)),
      ),
    );
  }
}

// ─── Top Header ───────────────────────────────────────────────────────────────
class _TopHeader extends StatelessWidget {
  final String title;
  final String? profileImageUrl;
  final VoidCallback onProfileTap;
  final Responsive r;
  final bool hideLogo;
  final bool isDesktop;
final ThemeProvider themeProvider;
  const _TopHeader({
    required this.title,
    required this.profileImageUrl,
    required this.onProfileTap,
    required this.r,
    this.hideLogo = false,
    this.isDesktop = false,
    required this.themeProvider, // ✅ Add this

  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeTokens.of(context);
    return Row(
      children: [
        if (!hideLogo) ...[
          Container(
            width: r.wp(44),
            height: r.wp(44),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.sageGreen, AppColors.sageGreen.withOpacity(0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(r.sp(13)),
              boxShadow: [BoxShadow(color: AppColors.sageGreen.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Image.asset('assets/icon/icon.png',
                  errorBuilder: (_, __, ___) => const Icon(Icons.favorite_rounded, color: Colors.white, size: 22)),
            ),
          ),
          SizedBox(width: r.wp(12)),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: isDesktop ? 22 : r.fs(21),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              if (!hideLogo)
                Text(
                  'Cardiac risk · clinical support',
                  style: TextStyle(color: t.textMuted, fontSize: r.fs(11), letterSpacing: 0.1),
                ),
            ],
          ),
        ),
        // Theme toggle
        Container(
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
        const SizedBox(width: 10),
        // Profile avatar — mobile only (desktop uses sidebar profile item)
        // if (!isDesktop)
        //   GestureDetector(
        //     onTap: onProfileTap,
        //     child: Container(
        //       width: r.wp(42),
        //       height: r.wp(42),
        //       decoration: BoxDecoration(
        //         shape: BoxShape.circle,
        //         border: Border.all(color: AppColors.sageGreen.withOpacity(0.4), width: 2),
        //         boxShadow: [BoxShadow(color: AppColors.sageGreen.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))],
        //       ),
        //       child: ClipOval(
        //         child: profileImageUrl != null
        //             ? CachedNetworkImage(
        //                 imageUrl: profileImageUrl!,
        //                 fit: BoxFit.cover,
        //                 placeholder: (_, __) => Container(color: t.surface, child: Icon(Icons.person_rounded, size: 18, color: t.textMuted)),
        //                 errorWidget: (_, __, ___) => Container(color: t.surface, child: Icon(Icons.person_rounded, size: 18, color: t.textMuted)),
        //               )
        //             : Container(color: t.surface, child: Icon(Icons.person_rounded, size: 18, color: t.textMuted)),
        //       ),
        //     ),
        //   ),
      ],
    );
  }
}

// ─── Section Title ────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;
  final Responsive r;
  final bool isDesktop;

  const _SectionTitle(this.text, this.r, {this.isDesktop = false});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeTokens.of(context);
    return Row(
      children: [
        Container(
          width: 4,
          height: isDesktop ? 20 : r.sp(18),
          decoration: BoxDecoration(
            color: AppColors.sageGreen,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            color: t.textPrimary,
            fontSize: isDesktop ? 17 : r.fs(17),
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

// In home_screen.dart - Replace _StatCard with this enhanced version

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Responsive r;
  final bool isDesktop;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.r,
    this.isDesktop = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeTokens.of(context);
    final isDark = t.isDark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(isDesktop ? 16 : r.sp(14)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(isDark ? 0.15 : 0.08),
              color.withOpacity(isDark ? 0.05 : 0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(isDesktop ? 16 : r.sp(16)),
          border: Border.all(
            color: color.withOpacity(isDark ? 0.2 : 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isDesktop
            ? Row(
                children: [
                  _buildIcon(color),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: t.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            color: t.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: t.textMuted.withOpacity(0.5),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildIcon(color),
                      Text(
                        value,
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: r.fs(24),
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: r.sp(8)),
                  Text(
                    title,
                    style: TextStyle(
                      color: t.textMuted,
                      fontSize: r.fs(10),
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildIcon(Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}


// ─── Patient Preview Card ─────────────────────────────────────────────────────
class _PatientPreviewCard extends StatelessWidget {
  final Map<String, dynamic> prediction;
  final String patientName;
  final String age;
  final String status;
  final String time;
  final VoidCallback onExport;
  final Responsive r;
  final bool isDesktop;

  const _PatientPreviewCard({
    required this.prediction,
    required this.patientName,
    required this.age,
    required this.status,
    required this.time,
    required this.onExport,
    required this.r,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeTokens.of(context);

    final Color tagColor = status == 'High Risk'
        ? const Color(0xFFC97C5D)
        : status == 'Moderate Risk'
            ? const Color(0xFFB89B5E)
            : AppColors.sageGreen;

    final parts = patientName.split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : patientName.isNotEmpty
            ? patientName[0].toUpperCase()
            : '?';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(isDesktop ? 16 : r.sp(16)),
        border: Border.all(color: t.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: t.textPrimary.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          // Initials avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tagColor.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: tagColor.withOpacity(0.2)),
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: tagColor,
                  fontSize: isDesktop ? 15 : r.fs(15),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patientName,
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: isDesktop ? 14 : r.fs(14),
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      'Age $age',
                      style: TextStyle(color: t.textMuted, fontSize: isDesktop ? 12 : r.fs(12)),
                    ),
                    Text(' · ', style: TextStyle(color: t.textMuted, fontSize: 12)),
                    Icon(Icons.access_time_rounded, size: 11, color: t.textMuted),
                    const SizedBox(width: 3),
                    Text(
                      time,
                      style: TextStyle(color: t.textMuted, fontSize: isDesktop ? 12 : r.fs(12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Risk badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tagColor.withOpacity(0.09),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tagColor.withOpacity(0.25)),
            ),
            child: Text(
              status.replaceAll(' Risk', ''),
              style: TextStyle(
                color: tagColor,
                fontSize: isDesktop ? 11 : r.fs(11),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // More menu
          PopupMenuButton<String>(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) { if (value == 'export') onExport(); },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_rounded, size: 17, color: t.textPrimary),
                    const SizedBox(width: 10),
                    Text('Export PDF', style: TextStyle(color: t.textPrimary, fontSize: 13)),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: t.surface,
                shape: BoxShape.circle,
                border: Border.all(color: t.border.withOpacity(0.5)),
              ),
              child: Icon(Icons.more_vert_rounded, color: t.textMuted, size: 17),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Loading Skeletons ────────────────────────────────────────────────────────
class _StatsLoadingSkeleton extends StatefulWidget {
  final bool isDesktop;
  final Responsive r;

  const _StatsLoadingSkeleton({required this.isDesktop, required this.r});

  @override
  State<_StatsLoadingSkeleton> createState() => _StatsLoadingSkeletonState();
}

class _StatsLoadingSkeletonState extends State<_StatsLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeTokens.of(context);
    final r = widget.r;

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final shimmer = Color.lerp(t.card, t.card.withOpacity(0.5), _anim.value)!;
        if (widget.isDesktop) {
          return Column(children: [
            _SkeletonBox(color: shimmer, height: 64, radius: 14),
            const SizedBox(height: 10),
            _SkeletonBox(color: shimmer, height: 64, radius: 14),
            const SizedBox(height: 10),
            _SkeletonBox(color: shimmer, height: 64, radius: 14),
          ]);
        }
        return Row(children: [
          Expanded(child: _SkeletonBox(color: shimmer, height: 68, radius: r.sp(16))),
          SizedBox(width: r.wp(10)),
          Expanded(child: _SkeletonBox(color: shimmer, height: 68, radius: r.sp(16))),
          SizedBox(width: r.wp(10)),
          Expanded(child: _SkeletonBox(color: shimmer, height: 68, radius: r.sp(16))),
        ]);
      },
    );
  }
}


// Quick Action Chip Widget
class _QuickActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Responsive r;

  const _QuickActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.wp(14), vertical: r.sp(8)),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(r.sp(12)),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: r.wp(14), color: color),
            SizedBox(width: r.wp(6)),
            Text(
              label,
              style: TextStyle(
                fontSize: r.fs(11),
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class _CasesLoadingSkeleton extends StatefulWidget {
  final Responsive r;
  final AppThemeTokens t;
  const _CasesLoadingSkeleton({required this.r, required this.t});

  @override
  State<_CasesLoadingSkeleton> createState() => _CasesLoadingSkeletonState();
}

class _CasesLoadingSkeletonState extends State<_CasesLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final r = widget.r;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final shimmer = Color.lerp(t.card, t.card.withOpacity(0.5), _anim.value)!;
        return Column(children: [
          _SkeletonBox(color: shimmer, height: 68, radius: r.sp(16)),
          SizedBox(height: r.sp(10)),
          _SkeletonBox(color: shimmer, height: 68, radius: r.sp(16)),
          SizedBox(height: r.sp(10)),
          _SkeletonBox(color: shimmer, height: 68, radius: r.sp(16)),
        ]);
      },
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final Color color;
  final double height;
  final double radius;
  const _SkeletonBox({required this.color, required this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ─── Empty Cases State ────────────────────────────────────────────────────────
class _EmptyCasesState extends StatelessWidget {
  final Responsive r;
  final AppThemeTokens t;
  final bool isDesktop;
  final VoidCallback onNewPrediction;

  const _EmptyCasesState({
    required this.r,
    required this.t,
    required this.isDesktop,
    required this.onNewPrediction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: isDesktop ? 32 : r.sp(32)),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(isDesktop ? 18 : r.sp(18)),
              decoration: BoxDecoration(
                color: AppColors.sageGreen.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inbox_rounded, size: isDesktop ? 36 : r.wp(36), color: AppColors.sageGreen.withOpacity(0.4)),
            ),
            SizedBox(height: isDesktop ? 14 : r.sp(14)),
            Text(
              'No predictions yet',
              style: TextStyle(
                color: t.textPrimary,
                fontSize: isDesktop ? 15 : r.fs(15),
                fontWeight: FontWeight.w700,
              ),
            ),
            // SizedBox(height: isDesktop ? 6 : r.sp(6)),
            // Text(
            //   'Tap "New Prediction" to get started.',
            //   textAlign: TextAlign.center,
            //   style: TextStyle(color: t.textMuted, fontSize: isDesktop ? 13 : r.fs(13), height: 1.5),
            // ),
            // SizedBox(height: isDesktop ? 18 : r.sp(18)),
            // ElevatedButton.icon(
            //   onPressed: onNewPrediction,
            //   icon: const Icon(Icons.add_chart_rounded, size: 16),
            //   label: const Text('New Prediction', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: AppColors.sageGreen,
            //     foregroundColor: Colors.white,
            //     elevation: 0,
            //     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}

// ─── Nav Item (Mobile) ────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Responsive r;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeTokens.of(context);
    final color = selected ? AppColors.sageGreen : t.textMuted.withOpacity(0.5);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: EdgeInsets.symmetric(vertical: r.sp(7), horizontal: r.wp(3)),
          decoration: BoxDecoration(
            color: selected ? AppColors.sageGreen.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(r.sp(12)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: r.wp(21)),
              SizedBox(height: r.sp(3)),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: r.fs(9),
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Simple Stat Item ─────────────────────────────────────────────────────────
// ─── Floating Stat Card (Warm Card banner) ────────────────────────────────────
// Elevated card designed to sit half on/half off the bottom edge of the
// gradient banner — opaque surface + real shadow so it visually "floats".
class _FloatingStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Responsive r;
  final bool isDesktop;

  const _FloatingStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.r,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isDesktop ? 14 : r.sp(13),
        horizontal: isDesktop ? 12 : r.sp(8),
      ),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(isDesktop ? 16 : r.sp(16)),
        border: Border.all(color: t.border.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(t.isDark ? 0.35 : 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isDesktop ? 28 : r.sp(26),
            height: isDesktop ? 28 : r.sp(26),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(isDesktop ? 9 : r.sp(8)),
            ),
            child: Icon(icon, size: isDesktop ? 15 : r.sp(14), color: color),
          ),
          SizedBox(height: isDesktop ? 6 : r.sp(6)),
          Text(
            value,
            style: TextStyle(
              fontSize: isDesktop ? 17 : r.fs(16),
              fontWeight: FontWeight.w800,
              color: t.textPrimary,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isDesktop ? 10.5 : r.fs(9.5),
              color: t.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleStatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Responsive r;

  const _SimpleStatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeTokens.of(context);
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: r.sp(12), horizontal: r.sp(10)),
        decoration: BoxDecoration(
          color: t.card.withOpacity(0.5),
          borderRadius: BorderRadius.circular(r.sp(12)),
          border: Border.all(color: t.border.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: r.sp(14), color: color),
                const SizedBox(width: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: r.fs(18),
                    fontWeight: FontWeight.w800,
                    color: t.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: r.fs(10),
                color: t.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─── Center Predict Button (Mobile) ──────────────────────────────────────────
class _CenterPredictButton extends StatelessWidget {
  final VoidCallback onTap;
  final Responsive r;

  const _CenterPredictButton({required this.onTap, required this.r});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: r.wp(52),
        height: r.wp(52),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.sageGreen, Color(0xFF2D7D5C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.sageGreen.withOpacity(0.45),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(Icons.add_rounded, color: Colors.white, size: r.wp(28)),
      ),
    );
  }
}

// ─── Primary / Secondary Action Buttons ──────────────────────────────────────
class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Responsive r;
  final bool isDesktop;

  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.r,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: isDesktop ? 17 : r.wp(17)),
        label: Text(label, style: TextStyle(fontSize: isDesktop ? 13 : r.fs(13), fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sageGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Responsive r;
  final bool isDesktop;

  const _SecondaryActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.r,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeTokens.of(context);
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: isDesktop ? 17 : r.wp(17)),
        label: Text(label, style: TextStyle(fontSize: isDesktop ? 13 : r.fs(13), fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          foregroundColor: t.textPrimary,
          side: BorderSide(color: t.border.withOpacity(0.7)),
          backgroundColor: t.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
      ),
    );
  }
}