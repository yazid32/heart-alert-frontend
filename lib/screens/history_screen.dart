import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/token_service.dart';
import '../services/api_service.dart';
import '../services/pdf_service.dart';
import '../utils/responsive_utils.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _predictions = [];
  List<dynamic> _filteredPredictions = [];
  String _searchQuery = '';
  String _selectedFilter = 'All';
  int _currentPage = 0;
  int _totalPages = 1;
  final int _pageSize = 10;

  final List<String> _filterOptions = [
    'All',
    'High Risk',
    'Moderate Risk',
    'Low Risk'
  ];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        final history = await ApiService.getHistory(token);
        final predictions = history['predictions'] ?? [];
        predictions.sort((a, b) =>
            DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));
        setState(() {
          _predictions = predictions;
          _filteredPredictions = _predictions;
          _totalPages = _filteredPredictions.isEmpty
              ? 1
              : (_filteredPredictions.length / _pageSize).ceil();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePrediction(Map<String, dynamic> prediction) async {
    final t = AppThemeTokens.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dt = AppThemeTokens.of(context);
        return AlertDialog(
          backgroundColor: dt.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Delete Prediction', style: TextStyle(color: dt.textPrimary)),
          content: Text(
            'Are you sure you want to delete prediction for ${_getPatientName(prediction)}?',
            style: TextStyle(color: dt.textMuted, height: 1.5),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: TextStyle(color: dt.textPrimary))),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete')),
          ],
        );
      },
    );
    if (confirm != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleting prediction...')));

    try {
      final token = await TokenService.getToken();
      if (token != null) {
        await ApiService.deletePrediction(
            token: token, predictionId: prediction['id']);
        await _fetchHistory();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Prediction deleted successfully')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  Future<void> _exportPrediction(Map<String, dynamic> prediction,
      {bool share = false}) async {
    try {
      await PdfService.exportPrediction(prediction, share: share);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to export PDF: $e')));
    }
  }

  String _getPatientName(Map<String, dynamic> p) {
    if (p['patient_name'] != null && p['patient_name'].toString().isNotEmpty)
      return p['patient_name'];
    return 'Patient ${p['id']}';
  }

  void _applyFilters() {
    List<dynamic> filtered = List.from(_predictions);
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((p) => _getPatientName(p)
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()))
          .toList();
    }
    if (_selectedFilter != 'All') {
      final cat = _selectedFilter == 'High Risk'
          ? 'high'
          : _selectedFilter == 'Moderate Risk'
              ? 'moderate'
              : 'low';
      filtered = filtered.where((p) => p['risk_category'] == cat).toList();
    }
    setState(() {
      _filteredPredictions = filtered;
      _totalPages = _filteredPredictions.isEmpty
          ? 1
          : (_filteredPredictions.length / _pageSize).ceil();
      _currentPage = 0;
    });
  }

  String _formatDate(String dateTimeStr) {
    try {
      final date = DateTime.parse(dateTimeStr);
      final difference = DateTime.now().difference(date);
      if (difference.inDays == 0) {
        if (difference.inHours < 1) {
          if (difference.inMinutes < 1) return 'Just now';
          return '${difference.inMinutes} min ago';
        }
        return '${difference.inHours} hr ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      }
      return DateFormat('MMM d, yyyy').format(date);
    } catch (_) {
      return dateTimeStr;
    }
  }

  Color _getRiskColor(String c) =>
      c == 'high' ? const Color(0xFFC97C5D) :
      c == 'moderate' ? const Color(0xFFB89B5E) : AppColors.sageGreen;

  String _getRiskDisplay(String c) =>
      c == 'high' ? 'High Risk' :
      c == 'moderate' ? 'Moderate Risk' : 'Low Risk';

  void _viewPredictionDetails(Map<String, dynamic> prediction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PredictionDetailSheet(
        prediction: prediction,
        patientName: _getPatientName(prediction),
        onExport: () => _exportPrediction(prediction),
        onShare: () => _exportPrediction(prediction, share: true),
        onDelete: () => _deletePrediction(prediction),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text(
          'History',
          style: TextStyle(
            fontSize: r.fs(18),
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: t.textPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchHistory,
              color: AppColors.sageGreen,
              backgroundColor: t.surface,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWeb = constraints.maxWidth > 600;
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isWeb ? 1200 : double.infinity),
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: r.hp, vertical: r.sp(10)),
                            child: Container(
                              height: r.sp(48),
                              decoration: BoxDecoration(
                                color: t.card.withOpacity(t.isDark ? 1.0 : 0.6),
                                borderRadius: BorderRadius.circular(r.cardRadius),
                                border: Border.all(color: t.border),
                              ),
                              child: TextField(
                                onChanged: (v) {
                                  _searchQuery = v;
                                  _applyFilters();
                                },
                                style: TextStyle(
                                    fontSize: r.fs(14), color: t.textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'Search by patient name...',
                                  hintStyle: TextStyle(
                                    color: t.textMuted,
                                    fontSize: r.fs(14),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: t.textMuted,
                                    size: r.wp(20),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                      vertical: r.sp(12)),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: r.sp(38),
                            child: ListView.separated(
                              padding: EdgeInsets.symmetric(horizontal: r.hp),
                              scrollDirection: Axis.horizontal,
                              itemCount: _filterOptions.length,
                              separatorBuilder: (_, __) =>
                                  SizedBox(width: r.wp(8)),
                              itemBuilder: (context, i) {
                                final filter = _filterOptions[i];
                                final isSelected = _selectedFilter == filter;
                                return FilterChip(
                                  label: Text(filter,
                                      style: TextStyle(fontSize: r.fs(12))),
                                  selected: isSelected,
                                  onSelected: (_) {
                                    setState(() => _selectedFilter = filter);
                                    _applyFilters();
                                  },
                                  backgroundColor: t.card.withOpacity(
                                      t.isDark ? 1.0 : 0.6),
                                  selectedColor: AppColors.sageGreen,
                                  side: BorderSide(
                                    color: isSelected
                                        ? AppColors.sageGreen
                                        : t.border,
                                    width: 1,
                                  ),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: r.wp(4)),
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : t.textPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                  shape: StadiumBorder(
                                    side: BorderSide(
                                      color: isSelected
                                          ? Colors.transparent
                                          : t.border,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(height: r.sp(10)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: r.hp),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_filteredPredictions.length} predictions',
                                  style: TextStyle(
                                      color: t.textMuted,
                                      fontSize: r.fs(12)),
                                ),
                                if (_filteredPredictions.isNotEmpty)
                                  Text(
                                    'Page ${_currentPage + 1} of $_totalPages',
                                    style: TextStyle(
                                        color: t.textMuted,
                                        fontSize: r.fs(12)),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(height: r.sp(6)),
                          Expanded(
                            child: _filteredPredictions.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.history,
                                          size: r.wp(56),
                                          color: t.textMuted,
                                        ),
                                        SizedBox(height: r.sp(14)),
                                        Text(
                                          'No predictions found',
                                          style: TextStyle(
                                              color: t.textMuted,
                                              fontSize: r.fs(15)),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: r.hp, vertical: r.sp(6)),
                                    itemCount: _filteredPredictions.length,
                                    itemBuilder: (context, i) {
                                      final p = _filteredPredictions[i];
                                      return _PredictionCard(
                                        prediction: p,
                                        patientName: _getPatientName(p),
                                        riskColor:
                                            _getRiskColor(p['risk_category']),
                                        riskDisplay:
                                            _getRiskDisplay(p['risk_category']),
                                        dateDisplay:
                                            _formatDate(p['created_at']),
                                        onTap: () =>
                                            _viewPredictionDetails(p),
                                        onExport: () => _exportPrediction(p),
                                        onShare: () =>
                                            _exportPrediction(p, share: true),
                                        onDelete: () => _deletePrediction(p),
                                        r: r,
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

// ── Prediction card ──────────────────────────
class _PredictionCard extends StatelessWidget {
  final Map<String, dynamic> prediction;
  final String patientName;
  final Color riskColor;
  final String riskDisplay;
  final String dateDisplay;
  final VoidCallback onTap;
  final VoidCallback onExport;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final Responsive r;

  const _PredictionCard({
    required this.prediction,
    required this.patientName,
    required this.riskColor,
    required this.riskDisplay,
    required this.dateDisplay,
    required this.onTap,
    required this.onExport,
    required this.onShare,
    required this.onDelete,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeTokens.of(context);
    final riskScore = (prediction['risk_score'] as double) * 100;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: r.sp(10)),
        padding: EdgeInsets.all(r.sp(14)),
        decoration: BoxDecoration(
          color: t.card.withOpacity(t.isDark ? 1.0 : 0.6),
          borderRadius: BorderRadius.circular(r.cardRadius),
          border: Border.all(color: t.border),
          boxShadow: [
            BoxShadow(
              color: t.textPrimary.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    patientName,
                    style: TextStyle(
                      fontSize: r.fs(15),
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                PopupMenuButton<String>(
                  color: t.surface,
                  onSelected: (value) {
                    if (value == 'export') onExport();
                    if (value == 'share') onShare();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                        value: 'export',
                        child: Row(children: [
                          Icon(Icons.picture_as_pdf,
                              size: 18, color: t.textPrimary),
                          const SizedBox(width: 8),
                          Text('Save PDF',
                              style: TextStyle(color: t.textPrimary))
                        ])),
                    PopupMenuItem(
                        value: 'share',
                        child: Row(children: [
                          Icon(Icons.share, size: 18, color: t.textPrimary),
                          const SizedBox(width: 8),
                          Text('Share PDF',
                              style: TextStyle(color: t.textPrimary))
                        ])),
                    PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          const Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          const SizedBox(width: 8),
                          const Text('Delete',
                              style: TextStyle(color: Colors.red))
                        ])),
                  ],
                  child: Icon(Icons.more_vert,
                      color: t.textMuted, size: r.wp(20)),
                ),
              ],
            ),
            SizedBox(height: r.sp(8)),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.wp(9), vertical: r.sp(4)),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(riskDisplay,
                      style: TextStyle(
                        color: riskColor,
                        fontSize: r.fs(11),
                        fontWeight: FontWeight.w700,
                      )),
                ),
                SizedBox(width: r.wp(8)),
                Text(
                  '${riskScore.toInt()}% risk',
                  style: TextStyle(color: t.textMuted, fontSize: r.fs(12)),
                ),
                const Spacer(),
                Text(
                  dateDisplay,
                  style: TextStyle(color: t.textMuted, fontSize: r.fs(11)),
                ),
              ],
            ),
            if (prediction['age'] != null) ...[
              SizedBox(height: r.sp(6)),
              Text(
                'Age ${prediction['age']} · ${prediction['gender'] ?? ''}',
                style: TextStyle(color: t.textMuted, fontSize: r.fs(12)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Detail bottom sheet ──────────────────────
class _PredictionDetailSheet extends StatelessWidget {
  final Map<String, dynamic> prediction;
  final String patientName;
  final VoidCallback onExport;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const _PredictionDetailSheet({
    required this.prediction,
    required this.patientName,
    required this.onExport,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);
    final riskScore = (prediction['risk_score'] as double) * 100;
    final riskCat = prediction['risk_category'] ?? 'low';
    final riskColor = riskCat == 'high'
        ? const Color(0xFFC97C5D)
        : riskCat == 'moderate'
            ? const Color(0xFFB89B5E)
            : AppColors.sageGreen;

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    String getChestPainType(int? cp) {
      switch (cp) {
        case 0: return 'Typical Angina';
        case 1: return 'Atypical Angina';
        case 2: return 'Non-anginal Pain';
        case 3: return 'Asymptomatic';
        default: return 'Unknown';
      }
    }

    String getRestingECGType(int? restecg) {
      switch (restecg) {
        case 0: return 'Normal';
        case 1: return 'ST-T Abnormality';
        case 2: return 'Left Ventricular Hypertrophy';
        default: return 'Unknown';
      }
    }

    String getSlopeType(int? slope) {
      switch (slope) {
        case 0: return 'Upsloping';
        case 1: return 'Flat';
        case 2: return 'Downsloping';
        default: return 'Unknown';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.sp(28))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Padding(
              padding: EdgeInsets.only(top: r.sp(16), bottom: r.sp(8)),
              child: Container(
                width: r.wp(15),
                height: r.sp(5),
                decoration: BoxDecoration(
                  color: t.textMuted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(r.sp(3)),
                ),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: r.hp),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patientName,
                              style: TextStyle(
                                fontSize: r.fs(24),
                                fontWeight: FontWeight.w800,
                                color: t.textPrimary,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: r.sp(8)),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: r.wp(5),
                                vertical: r.sp(6),
                              ),
                              decoration: BoxDecoration(
                                color: riskColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(r.sp(20)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: r.sp(8),
                                    height: r.sp(8),
                                    decoration: BoxDecoration(
                                      color: riskColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: r.wp(3)),
                                  Text(
                                    '${riskScore.toInt()}% · ${riskCat.toUpperCase()} RISK',
                                    style: TextStyle(
                                      color: riskColor,
                                      fontSize: r.fs(12),
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: r.wp(4),
                          vertical: r.sp(6),
                        ),
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius: BorderRadius.circular(r.sp(12)),
                          border: Border.all(color: t.border),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.calendar_today,
                                size: r.sp(16), color: t.textMuted),
                            SizedBox(height: r.sp(4)),
                            Text(
                              _formatDateShort(prediction['created_at']),
                              style: TextStyle(
                                fontSize: r.fs(10),
                                color: t.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: r.sp(24)),
                  Row(
                    children: [
                      Container(
                        width: r.sp(4),
                        height: r.sp(20),
                        decoration: BoxDecoration(
                          color: AppColors.sageGreen,
                          borderRadius: BorderRadius.circular(r.sp(2)),
                        ),
                      ),
                      SizedBox(width: r.wp(3)),
                      Text(
                        'CLINICAL DATA',
                        style: TextStyle(
                          fontSize: r.fs(13),
                          fontWeight: FontWeight.w700,
                          color: t.textMuted,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: r.sp(16)),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.cake_outlined,
                          label: 'Age',
                          value: '${prediction['age'] ?? '-'} years',
                          t: t,
                          r: r,
                        ),
                      ),
                      SizedBox(width: r.wp(4)),
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.transgender,
                          label: 'Gender',
                          value: prediction['sex'] == 1
                              ? 'Male'
                              : (prediction['sex'] == 0 ? 'Female' : '-'),
                          t: t,
                          r: r,
                        ),
                      ),
                      SizedBox(width: r.wp(4)),
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.favorite,
                          label: 'Max HR',
                          value: '${prediction['thalach'] ?? '-'} bpm',
                          t: t,
                          r: r,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: r.sp(12)),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.science_outlined,
                          label: 'Cholesterol',
                          value: '${prediction['chol'] ?? '-'} mg/dl',
                          t: t,
                          r: r,
                        ),
                      ),
                      SizedBox(width: r.wp(4)),
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.monitor_heart,
                          label: 'Resting BP',
                          value: '${prediction['trestbps'] ?? '-'} mm Hg',
                          t: t,
                          r: r,
                        ),
                      ),
                      SizedBox(width: r.wp(4)),
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.bloodtype,
                          label: 'Fasting BS',
                          value: prediction['fbs'] == 1
                              ? '>120 mg/dl'
                              : '≤120 mg/dl',
                          t: t,
                          r: r,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: r.sp(12)),
                  Container(
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(r.sp(16)),
                      border: Border.all(color: t.border),
                    ),
                    padding: EdgeInsets.all(r.sp(16)),
                    child: Column(
                      children: [
                        _DetailItem(
                          icon: Icons.health_and_safety,
                          label: 'Chest Pain',
                          value: getChestPainType(prediction['cp']),
                          t: t,
                          r: r,
                        ),
                        SizedBox(height: r.sp(12)),
                        Divider(color: t.border, height: 1),
                        SizedBox(height: r.sp(12)),
                        _DetailItem(
                          icon: Icons.favorite,
                          label: 'Resting ECG',
                          value: getRestingECGType(prediction['restecg']),
                          t: t,
                          r: r,
                        ),
                        SizedBox(height: r.sp(12)),
                        Divider(color: t.border, height: 1),
                        SizedBox(height: r.sp(12)),
                        _DetailItem(
                          icon: Icons.bolt,
                          label: 'ST Depression',
                          value: '${prediction['oldpeak'] ?? '-'} mm',
                          t: t,
                          r: r,
                        ),
                        SizedBox(height: r.sp(12)),
                        Divider(color: t.border, height: 1),
                        SizedBox(height: r.sp(12)),
                        _DetailItem(
                          icon: Icons.trending_up,
                          label: 'Slope',
                          value: getSlopeType(prediction['slope']),
                          t: t,
                          r: r,
                        ),
                        SizedBox(height: r.sp(12)),
                        Divider(color: t.border, height: 1),
                        SizedBox(height: r.sp(12)),
                        _DetailItem(
                          icon: Icons.directions_run,
                          label: 'Exercise Angina',
                          value: prediction['exang'] == 1 ? 'Yes' : 'No',
                          t: t,
                          r: r,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.sp(24)),
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: bottomPadding + r.sp(24),
                      left: r.wp(2),
                      right: r.wp(2),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.picture_as_pdf,
                            label: 'Save',
                            onTap: () {
                              Navigator.pop(context);
                              onExport();
                            },
                            isPrimary: false,
                            t: t,
                            r: r,
                          ),
                        ),
                        SizedBox(width: r.wp(8)),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.share,
                            label: 'Share',
                            onTap: () {
                              Navigator.pop(context);
                              onShare();
                            },
                            isPrimary: false,
                            t: t,
                            r: r,
                          ),
                        ),
                        SizedBox(width: r.wp(8)),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.delete_outline,
                            label: 'Delete',
                            onTap: () {
                              Navigator.pop(context);
                              onDelete();
                            },
                            isPrimary: false,
                            isDanger: true,
                            t: t,
                            r: r,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateShort(String dateTimeStr) {
    try {
      final date = DateTime.parse(dateTimeStr);
      return DateFormat('MMM d').format(date);
    } catch (_) {
      return '';
    }
  }
}

// Helper Widget: Info Card
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final AppThemeTokens t;
  final Responsive r;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.t,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(r.sp(12)),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(r.sp(12)),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: r.sp(20), color: AppColors.sageGreen),
          SizedBox(height: r.sp(6)),
          Text(
            value,
            style: TextStyle(
              fontSize: r.fs(13),
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: r.fs(10),
              color: t.textMuted,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Helper Widget: Detail Item
class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final AppThemeTokens t;
  final Responsive r;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.t,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(r.sp(8)),
          decoration: BoxDecoration(
            color: AppColors.sageGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(r.sp(10)),
          ),
          child: Icon(icon, size: r.sp(18), color: AppColors.sageGreen),
        ),
        SizedBox(width: r.wp(4)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: r.fs(11),
                  color: t.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: r.fs(14),
                  fontWeight: FontWeight.w600,
                  color: t.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Helper Widget: Action Button
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isDanger;
  final AppThemeTokens t;
  final Responsive r;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = true,
    this.isDanger = false,
    required this.t,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    Color getColor() {
      if (isDanger) return Colors.red;
      if (isPrimary) return AppColors.sageGreen;
      return t.textPrimary;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: r.sp(14)),
        decoration: BoxDecoration(
          color: isDanger ? Colors.red.withOpacity(0.1) : t.surface,
          borderRadius: BorderRadius.circular(r.sp(12)),
          border: Border.all(
            color: isDanger ? Colors.red.withOpacity(0.3) : t.border,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: r.sp(22), color: getColor()),
            SizedBox(height: r.sp(6)),
            Text(
              label,
              style: TextStyle(
                fontSize: r.fs(12),
                fontWeight: FontWeight.w600,
                color: getColor(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}