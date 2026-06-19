// lib/screens/admin_home_screen.dart
import 'package:flutter/material.dart';
import '../services/token_service.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_utils.dart';
import 'admin_users_screen.dart';
import 'admin_requests_screen.dart';
import 'admin_support_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;
  User? _currentUser;
  bool _isLoading = true;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _pages = const [
      AdminDashboardTab(),
      AdminUsersScreen(),
      AdminRequestsScreen(),
      AdminSupportScreen(),
    ];
  }

  void setCurrentIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    _currentUser = await TokenService.getUser();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);

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

    final isWide = MediaQuery.of(context).size.width >= 900;

    if (isWide) {
      return Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Row(
            children: [
              _AdminSidebar(
                currentIndex: _currentIndex,
                onSelect: setCurrentIndex,
                t: t,
              ),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: _pages,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: t.bg,
          border: Border(top: BorderSide(color: t.border.withOpacity(0.5), width: 1)),
          boxShadow: [BoxShadow(color: t.textPrimary.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, -8))],
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: r.wp(16), vertical: r.sp(10)),
            child: Container(
              height: r.sp(64),
              decoration: BoxDecoration(
                color: t.surface.withOpacity(t.isDark ? 0.25 : 0.85),
                borderRadius: BorderRadius.circular(r.sp(18)),
                border: Border.all(color: t.border.withOpacity(0.8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', selected: _currentIndex == 0, onTap: () => setCurrentIndex(0), r: r),
                  _NavItem(icon: Icons.people_rounded, label: 'Users', selected: _currentIndex == 1, onTap: () => setCurrentIndex(1), r: r),
                  _NavItem(icon: Icons.assignment_ind_rounded, label: 'Requests', selected: _currentIndex == 2, onTap: () => setCurrentIndex(2), r: r),
                  _NavItem(icon: Icons.support_agent_rounded, label: 'Support', selected: _currentIndex == 3, onTap: () => setCurrentIndex(3), r: r),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ========== DESKTOP / WEB SIDEBAR ==========
// Pure presentation: receives the current tab index and a setter, exactly
// mirroring what the bottom nav bar already does on mobile.
class _AdminSidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final AppThemeTokens t;

  const _AdminSidebar({
    required this.currentIndex,
    required this.onSelect,
    required this.t,
  });

  static const _items = [
    (Icons.dashboard_rounded, 'Dashboard'),
    (Icons.people_rounded, 'Users'),
    (Icons.assignment_ind_rounded, 'Requests'),
    (Icons.support_agent_rounded, 'Support'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: t.surface.withOpacity(t.isDark ? 0.4 : 1.0),
        border: Border(right: BorderSide(color: t.border.withOpacity(0.6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.sageGreen.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.sageGreen.withOpacity(0.3), width: 1.5),
                  ),
                  child: Center(
                    child: ClipOval(
                      child: Image.asset(
                        'assets/icon/icon.png',
                        width: 20,
                        height: 20,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: AppColors.sageGreen,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Admin Portal',
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: List.generate(_items.length, (i) {
                final selected = currentIndex == i;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onSelect(i),
                      borderRadius: BorderRadius.circular(12),
                      hoverColor: AppColors.sageGreen.withOpacity(0.06),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.sageGreen.withOpacity(0.10) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _items[i].$1,
                              size: 19,
                              color: selected ? AppColors.sageGreen : t.textPrimary.withOpacity(0.45),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _items[i].$2,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                                color: selected ? AppColors.sageGreen : t.textPrimary.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 15, color: t.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'System Control & Management',
                    style: TextStyle(fontSize: 11, color: t.textMuted),
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Responsive r;

  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap, required this.r});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeTokens.of(context);
    final activeColor = AppColors.sageGreen;
    final inactiveColor = t.textPrimary.withOpacity(0.35);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: EdgeInsets.symmetric(vertical: r.sp(6), horizontal: r.wp(4)),
          decoration: BoxDecoration(
            color: selected ? activeColor.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(r.sp(12)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? activeColor : inactiveColor, size: r.wp(20)),
              SizedBox(height: r.sp(2)),
              Text(label, style: TextStyle(color: selected ? activeColor : inactiveColor, fontSize: r.fs(10), fontWeight: selected ? FontWeight.w700 : FontWeight.w600, letterSpacing: 0.2)),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== DASHBOARD TAB ==========
class AdminDashboardTab extends StatelessWidget {
  const AdminDashboardTab({super.key});

  void _showStatsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _StatsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);
    final adminState = context.findAncestorStateOfType<_AdminHomeScreenState>();

    return RefreshIndicator(
      color: AppColors.sageGreen,
      backgroundColor: t.surface,
      onRefresh: () async => Future.delayed(const Duration(milliseconds: 500)),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(r.wp(16), r.sp(20), r.wp(16), r.sp(40)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AdminHeader(r: r, t: t),
            SizedBox(height: r.sp(28)),
            Text('Quick Actions', style: TextStyle(color: t.textPrimary, fontSize: r.fs(14), fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            SizedBox(height: r.sp(12)),
            Row(
              children: [
                Expanded(
                  child: _ActionGridCard(
                    icon: Icons.people_alt_rounded,
                    title: 'Manage\nUsers',
                    description: 'Doctors & Assistants',
                    onTap: () => adminState?.setCurrentIndex(1),
                    r: r,
                    t: t,
                  ),
                ),
                SizedBox(width: r.wp(12)),
                Expanded(
                  child: _ActionGridCard(
                    icon: Icons.assignment_ind_rounded,
                    title: 'Assistant\nRequests',
                    description: 'Pending Verifications',
                    onTap: () => adminState?.setCurrentIndex(2),
                    r: r,
                    t: t,
                  ),
                ),
              ],
            ),
            SizedBox(height: r.sp(12)),
            Row(
              children: [
                Expanded(
                  child: _ActionGridCard(
                    icon: Icons.analytics_rounded,
                    title: 'System\nStats',
                    description: 'View Analytics',
                    onTap: () => _showStatsDialog(context),
                    r: r,
                    t: t,
                  ),
                ),
                SizedBox(width: r.wp(12)),
                Expanded(
                  child: _ActionGridCard(
                    icon: Icons.support_agent_rounded,
                    title: 'Support\nTickets',
                    description: 'User Messages',
                    onTap: () => adminState?.setCurrentIndex(3),
                    r: r,
                    t: t,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ========== ADMIN HEADER ==========
class _AdminHeader extends StatelessWidget {
  final Responsive r;
  final AppThemeTokens t;

  const _AdminHeader({required this.r, required this.t});

  Future<void> _logout(BuildContext context) async {
    final confirm = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) => Container(),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: AlertDialog(
            backgroundColor: t.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Logout', style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
            content: Text('Are you sure you want to log out of the administrator panel?', style: TextStyle(color: t.textMuted)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: t.textMuted))),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );

    if (confirm == true) {
      await TokenService.deleteToken();
      if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: r.wp(46),
          height: r.wp(46),
          decoration: BoxDecoration(color: AppColors.sageGreen.withOpacity(0.12), shape: BoxShape.circle, border: Border.all(color: AppColors.sageGreen.withOpacity(0.3), width: 1.5)),
          child: Center(
            child: ClipOval(
              child: Image.asset(
                'assets/icon/icon.png',
                width: r.wp(26),
                height: r.wp(26),
                errorBuilder: (_, __, ___) => const Icon(Icons.admin_panel_settings_rounded, color: AppColors.sageGreen, size: 24),
              ),
            ),
          ),
        ),
        SizedBox(width: r.wp(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Admin Portal', style: TextStyle(color: t.textPrimary, fontSize: r.fs(20), fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              SizedBox(height: r.sp(2)),
              Text('System Control & Management', style: TextStyle(color: t.textMuted, fontSize: r.fs(12), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _logout(context),
          style: IconButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.08), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: EdgeInsets.all(r.sp(10))),
          icon: Icon(Icons.power_settings_new_rounded, color: Colors.red.shade400, size: r.wp(20)),
        ),
      ],
    );
  }
}

// ========== ACTION GRID CARD ==========
class _ActionGridCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Responsive r;
  final AppThemeTokens t;

  const _ActionGridCard({required this.icon, required this.title, required this.description, required this.onTap, required this.r, required this.t});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(r.sp(20)),
      child: Container(
        padding: EdgeInsets.all(r.sp(18)),
        decoration: BoxDecoration(
          color: t.card.withOpacity(t.isDark ? 0.4 : 1.0),
          borderRadius: BorderRadius.circular(r.sp(20)),
          border: Border.all(color: t.border.withOpacity(0.7)),
          boxShadow: [BoxShadow(color: t.textPrimary.withOpacity(t.isDark ? 0.0 : 0.02), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(padding: EdgeInsets.all(r.sp(10)), decoration: BoxDecoration(color: AppColors.sageGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(r.sp(14))), child: Icon(icon, color: AppColors.sageGreen, size: r.sp(24))),
            SizedBox(height: r.sp(24)),
            Text(title, style: TextStyle(color: t.textPrimary, fontSize: r.fs(15), fontWeight: FontWeight.w700, height: 1.2)),
            SizedBox(height: r.sp(4)),
            Text(description, style: TextStyle(color: t.textMuted, fontSize: r.fs(11), fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ========== STATS DIALOG - FIXED WITH SCROLLVIEW ==========
class _StatsDialog extends StatefulWidget {
  const _StatsDialog();

  @override
  State<_StatsDialog> createState() => _StatsDialogState();
}

class _StatsDialogState extends State<_StatsDialog> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        final stats = await ApiService.getAdminStats(token);
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: t.surface,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: r.wp(380),
          maxHeight: MediaQuery.of(context).size.height * 0.85, // Limit height to 85% of screen
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fixed Header - doesn't scroll
            Padding(
              padding: EdgeInsets.fromLTRB(r.sp(24), r.sp(24), r.sp(12), r.sp(12)),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(r.sp(10)),
                    decoration: BoxDecoration(
                      color: AppColors.sageGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(r.sp(12)),
                    ),
                    child: Icon(Icons.analytics_rounded, color: AppColors.sageGreen, size: r.sp(24)),
                  ),
                  SizedBox(width: r.sp(16)),
                  Expanded(
                    child: Text(
                      'System Statistics',
                      style: TextStyle(fontSize: r.fs(20), fontWeight: FontWeight.bold, color: t.textPrimary),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: t.textMuted),
                  ),
                ],
              ),
            ),
            
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: r.sp(24)),
                child: _isLoading
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(r.sp(40)),
                          child: const CircularProgressIndicator(),
                        ),
                      )
                    : _stats != null
                        ? Column(
                            children: [
                              _StatsSection(
                                title: '👥 Users',
                                children: [
                                  _StatsRow(
                                    label: 'Doctors',
                                    value: _stats!['doctors']?.toString() ?? '0',
                                    icon: Icons.medical_services_rounded,
                                    t: t,
                                  ),
                                  _StatsRow(
                                    label: 'Assistants',
                                    value: _stats!['assistants']?.toString() ?? '0',
                                    icon: Icons.person_outline,
                                    t: t,
                                  ),
                                  _StatsRow(
                                    label: 'Pending Approvals',
                                    value: _stats!['pending_approvals']?.toString() ?? '0',
                                    icon: Icons.pending_actions_rounded,
                                    highlight: (_stats!['pending_approvals'] ?? 0) > 0,
                                    t: t,
                                  ),
                                  _StatsRow(
                                    label: 'Email Verified',
                                    value: '${_stats!['verification_rate'] ?? 0}%',
                                    icon: Icons.verified_rounded,
                                    t: t,
                                  ),
                                ],
                              ),
                              SizedBox(height: r.sp(16)),
                              _StatsSection(
                                title: '📊 Predictions',
                                children: [
                                  _StatsRow(
                                    label: 'Total',
                                    value: _stats!['total_predictions']?.toString() ?? '0',
                                    icon: Icons.analytics_rounded,
                                    t: t,
                                  ),
                                  _StatsRow(
                                    label: 'Today',
                                    value: _stats!['today_predictions']?.toString() ?? '0',
                                    icon: Icons.today_rounded,
                                    t: t,
                                  ),
                                  _StatsRow(
                                    label: 'Last 7 days',
                                    value: _stats!['week_predictions']?.toString() ?? '0',
                                    icon: Icons.calendar_today_rounded,
                                    t: t,
                                  ),
                                ],
                              ),
                              SizedBox(height: r.sp(16)),
                              _StatsSection(
                                title: '💰 Subscriptions',
                                children: [
                                  _StatsRow(
                                    label: 'Pro Users',
                                    value: _stats!['pro_users']?.toString() ?? '0',
                                    icon: Icons.star_rounded,
                                    t: t,
                                  ),
                                  _StatsRow(
                                    label: 'Hospital Plans',
                                    value: _stats!['hospital_users']?.toString() ?? '0',
                                    icon: Icons.business_rounded,
                                    t: t,
                                  ),
                                ],
                              ),
                              SizedBox(height: r.sp(16)),
                              _StatsSection(
                                title: '🎫 Pending',
                                children: [
                                  _StatsRow(
                                    label: 'Assistant Requests',
                                    value: _stats!['pending_requests']?.toString() ?? '0',
                                    icon: Icons.assignment_ind_rounded,
                                    highlight: (_stats!['pending_requests'] ?? 0) > 0,
                                    t: t,
                                  ),
                                  _StatsRow(
                                    label: 'Open Support Tickets',
                                    value: _stats!['open_tickets']?.toString() ?? '0',
                                    icon: Icons.support_agent_rounded,
                                    highlight: (_stats!['open_tickets'] ?? 0) > 0,
                                    t: t,
                                  ),
                                ],
                              ),
                              SizedBox(height: r.sp(16)),
                            ],
                          )
                        : Center(
                            child: Padding(
                              padding: EdgeInsets.all(r.sp(40)),
                              child: Text(
                                'Failed to load statistics',
                                style: TextStyle(color: t.textMuted),
                              ),
                            ),
                          ),
              ),
            ),
            
            // Fixed Footer - doesn't scroll
            Padding(
              padding: EdgeInsets.fromLTRB(r.sp(24), r.sp(12), r.sp(24), r.sp(24)),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sageGreen,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: r.sp(14)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.sp(12))),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _StatsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.sp(12)),
      decoration: BoxDecoration(
        color: t.card.withOpacity(0.5),
        borderRadius: BorderRadius.circular(r.sp(16)),
        border: Border.all(color: t.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: r.fs(14), fontWeight: FontWeight.w600, color: t.textPrimary)),
          SizedBox(height: r.sp(8)),
          ...children,
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool highlight;
  final AppThemeTokens t;

  const _StatsRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.t,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.sp(6)),
      child: Row(
        children: [
          Icon(icon, size: r.sp(16), color: t.textMuted),
          SizedBox(width: r.sp(10)),
          Expanded(child: Text(label, style: TextStyle(fontSize: r.fs(13), color: t.textMuted))),
          Container(
            padding: EdgeInsets.symmetric(horizontal: r.wp(8), vertical: r.sp(2)),
            decoration: BoxDecoration(
              color: highlight ? AppColors.sageGreen.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(r.sp(6)),
              border: highlight ? Border.all(color: AppColors.sageGreen.withOpacity(0.3)) : null,
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: r.fs(15),
                fontWeight: FontWeight.w600,
                color: highlight ? AppColors.sageGreen : t.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}