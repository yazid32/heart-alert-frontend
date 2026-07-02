// lib/screens/hospital/hospital_dashboard_screen.dart
import 'package:flutter/material.dart';
import '../../services/token_service.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive_utils.dart';
import 'hospital_doctors_screen.dart';
import '../../theme/theme_provider.dart';
import 'package:provider/provider.dart';
class HospitalDashboardScreen extends StatefulWidget {
  const HospitalDashboardScreen({super.key});

  @override
  State<HospitalDashboardScreen> createState() =>
      _HospitalDashboardScreenState();
}

class _HospitalDashboardScreenState extends State<HospitalDashboardScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  late AnimationController _navController;

  @override
  void initState() {
    super.initState();
    _navController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _loadStats();
  }

  @override
  void dispose() {
    _navController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        final stats = await ApiService.getHospitalStats(token);
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading stats: $e');
    }
  }

  void _setIndex(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);
    final themeProvider = context.watch<ThemeProvider>(); // ✅ Add this

    // 1. Wrap the entire Scaffold in LayoutBuilder to determine screen type safely
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWeb = constraints.maxWidth > 768;

        return Scaffold(
          backgroundColor: t.bg,
          // 2. Hide the bottom nav bar completely when on web/desktop view
          bottomNavigationBar: isWeb
              ? null
              : _HospitalNavBar(
                  currentIndex: _currentIndex,
                  onTap: _setIndex,
                  r: r,
                  t: t,
                ),
          body: SafeArea(
            child: Row(
              children: [
                // 3. Show a sleek sidebar on the left side for web/desktop view
                if (isWeb)
                  _HospitalSideBar(
                    currentIndex: _currentIndex,
                    onTap: _setIndex,
                    r: r,
                    t: t,
                  ),
                
                // Main content canvas
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isWeb ? 1000 : double.infinity,
                      ),
                      child: IndexedStack(
                        index: _currentIndex,
                        children: [
                          HospitalHomeTab(
                            stats: _stats,
                            isLoading: _isLoading,
                            onRefresh: _loadStats,
                          ),
                          const HospitalDoctorsScreen(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Web/Desktop Sidebar ───────────────────────────────────────────────────────
class _HospitalSideBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Responsive r;
  final AppThemeTokens t;

  const _HospitalSideBar({
    required this.currentIndex,
    required this.onTap,
    required this.r,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: double.infinity,
      decoration: BoxDecoration(
        color: t.card,
        border: Border(right: BorderSide(color: t.border.withOpacity(0.4))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Branding/Header item inside sidebar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.local_hospital_rounded, color: AppColors.sageGreen, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Hospital Portal',
                    style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Navigation Items
            _SideNavItem(
              icon: Icons.dashboard_rounded,
              label: 'Dashboard',
              selected: currentIndex == 0,
              onTap: () => onTap(0),
              t: t,
            ),
            const SizedBox(height: 8),
            _SideNavItem(
              icon: Icons.medical_services_rounded,
              label: 'Doctors',
              selected: currentIndex == 1,
              onTap: () => onTap(1),
              t: t,
            ),
          ],
        ),
      ),
    );
  }
}

class _SideNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppThemeTokens t;

  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.sageGreen;
    final inactiveColor = t.textPrimary.withOpacity(0.4);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? activeColor.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? activeColor : inactiveColor,
              size: 22,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: selected ? activeColor : t.textPrimary,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mobile Bottom Nav Bar ─────────────────────────────────────────────────────
class _HospitalNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Responsive r;
  final AppThemeTokens t;

  const _HospitalNavBar({
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
        border: Border(top: BorderSide(color: t.border.withOpacity(0.4))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(t.isDark ? 0.2 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: r.wp(20), vertical: r.sp(10)),
          child: Container(
            height: r.sp(62),
            decoration: BoxDecoration(
              color: t.isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(r.sp(18)),
              border: Border.all(color: t.border.withOpacity(0.6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  selected: currentIndex == 0,
                  onTap: () => onTap(0),
                  r: r,
                ),
                _NavItem(
                  icon: Icons.medical_services_rounded,
                  label: 'Doctors',
                  selected: currentIndex == 1,
                  onTap: () => onTap(1),
                  r: r,
                ),
              ],
            ),
          ),
        ),
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
    const active = AppColors.sageGreen;
    final inactive = t.textPrimary.withOpacity(0.3);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: EdgeInsets.symmetric(
              vertical: r.sp(6), horizontal: r.wp(6)),
          decoration: BoxDecoration(
            color: selected ? active.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(r.sp(12)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  icon,
                  key: ValueKey(selected),
                  color: selected ? active : inactive,
                  size: r.wp(20),
                ),
              ),
              SizedBox(height: r.sp(2)),
              Text(
                label,
                style: TextStyle(
                  color: selected ? active : inactive,
                  fontSize: r.fs(10),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

class HospitalHomeTab extends StatelessWidget {
  final Map<String, dynamic>? stats;
  final bool isLoading;
  final VoidCallback onRefresh;

  const HospitalHomeTab({
    super.key,
    required this.stats,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return RefreshIndicator(
          color: AppColors.sageGreen,
          backgroundColor: t.surface,
          onRefresh: () async => onRefresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(r.wp(16), r.sp(20), r.wp(16), r.sp(48)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HospitalHeader(
                  r: r,
                  t: t,
                  themeProvider: themeProvider,
                ),
                SizedBox(height: r.sp(28)),
                if (isLoading)
                  _LoadingGrid(r: r, t: t)
                else if (stats != null) ...[
                  _StatsSection(stats: stats!, r: r, t: t),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
// ── Loading skeleton grid ─────────────────────────────────────────────────────
class _LoadingGrid extends StatelessWidget {
  final Responsive r;
  final AppThemeTokens t;

  const _LoadingGrid({required this.r, required this.t});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _SkeletonCard(r: r, t: t)),
            SizedBox(width: r.wp(12)),
            Expanded(child: _SkeletonCard(r: r, t: t)),
          ],
        ),
        SizedBox(height: r.sp(12)),
        Row(
          children: [
            Expanded(child: _SkeletonCard(r: r, t: t)),
            SizedBox(width: r.wp(12)),
            Expanded(child: _SkeletonCard(r: r, t: t)),
          ],
        ),
      ],
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  final Responsive r;
  final AppThemeTokens t;

  const _SkeletonCard({required this.r, required this.t});

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final t = widget.t;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        height: r.sp(110),
        padding: EdgeInsets.all(r.sp(16)),
        decoration: BoxDecoration(
          color: Color.lerp(
            t.card,
            t.card.withOpacity(0.5),
            _anim.value,
          ),
          borderRadius: BorderRadius.circular(r.sp(16)),
          border: Border.all(color: t.border.withOpacity(0.5)),
        ),
      ),
    );
  }
}

// ── Stats Section ─────────────────────────────────────────────────────────────
class _StatsSection extends StatelessWidget {
  final Map<String, dynamic> stats;
  final Responsive r;
  final AppThemeTokens t;

  const _StatsSection({required this.stats, required this.r, required this.t});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: TextStyle(
            fontSize: r.fs(13),
            fontWeight: FontWeight.w800,
            color: t.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: r.sp(12)),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Total Doctors',
                value: '${stats['total_doctors'] ?? 0}',
                icon: Icons.people_rounded,
                color: AppColors.sageGreen,
                r: r,
                t: t,
              ),
            ),
            SizedBox(width: r.wp(12)),
            Expanded(
              child: _StatCard(
                title: 'Total Patients',
                value: '${stats['total_patients'] ?? 0}',
                icon: Icons.person_rounded,
                color: const Color(0xFF3B82F6),
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
              child: _StatCard(
                title: 'Total Predictions',
                value: '${stats['total_predictions'] ?? 0}',
                icon: Icons.analytics_rounded,
                color: const Color(0xFF8B5CF6),
                r: r,
                t: t,
              ),
            ),
            SizedBox(width: r.wp(12)),
            Expanded(
              child: _StatCard(
                title: 'Total Assistants',
                value: '${stats['total_assistants'] ?? 0}',
                icon: Icons.support_agent_rounded,
                color: const Color(0xFFF59E0B),
                r: r,
                t: t,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HospitalHeader extends StatelessWidget {
  final Responsive r;
  final AppThemeTokens t;
  final ThemeProvider themeProvider;

  const _HospitalHeader({
    required this.r,
    required this.t,
    required this.themeProvider,
  });

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign out',
            style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to sign out?',
            style: TextStyle(color: t.textMuted, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: t.textMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign out',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await TokenService.deleteToken();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Hospital avatar
        Container(
          width: r.wp(46),
          height: r.wp(46),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.sageGreen.withOpacity(0.8),
                AppColors.sageGreen,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(Icons.local_hospital_rounded,
                color: Colors.white, size: r.wp(24)),
          ),
        ),
        SizedBox(width: r.wp(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hospital Portal',
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: r.fs(20),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
              SizedBox(height: r.sp(2)),
              Text(
                'Manage your hospital',
                style: TextStyle(
                    color: t.textMuted,
                    fontSize: r.fs(12),
                    fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ),
        // ✅ Theme Toggle
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
        SizedBox(width: r.wp(8)),
        // Sign out button
        GestureDetector(
          onTap: () => _logout(context),
          child: Container(
            padding: EdgeInsets.all(r.sp(10)),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.07),
              borderRadius: BorderRadius.circular(r.sp(12)),
              border: Border.all(color: Colors.red.withOpacity(0.15)),
            ),
            child: Icon(Icons.power_settings_new_rounded,
                color: Colors.red.shade400, size: r.wp(18)),
          ),
        ),
      ],
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Responsive r;
  final AppThemeTokens t;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.r,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(r.sp(16)),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(r.sp(16)),
        border: Border.all(color: t.border.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(r.sp(8)),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(r.sp(10)),
                ),
                child: Icon(icon, color: color, size: r.sp(18)),
              ),
            ],
          ),
          SizedBox(height: r.sp(14)),
          Text(
            value,
            style: TextStyle(
              fontSize: r.fs(26),
              fontWeight: FontWeight.w800,
              color: t.textPrimary,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
          SizedBox(height: r.sp(4)),
          Text(
            title,
            style: TextStyle(
                fontSize: r.fs(11),
                color: t.textMuted,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}