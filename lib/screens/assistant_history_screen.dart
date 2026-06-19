// lib/screens/assistant_history_screen.dart
import 'package:flutter/material.dart';
import '../services/token_service.dart';
import '../services/api_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_utils.dart';

class AssistantHistoryScreen extends StatefulWidget {
  const AssistantHistoryScreen({super.key});

  @override
  State<AssistantHistoryScreen> createState() => _AssistantHistoryScreenState();
}

class _AssistantHistoryScreenState extends State<AssistantHistoryScreen> {
  List<dynamic> _predictions = [];
  bool _isLoading = true;
  String _filter = 'all';
  String? _error;

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
        final response = await ApiService.getHistory(token);
        setState(() {
          _predictions = response['predictions'] ?? [];
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredPredictions {
    if (_filter == 'all') return _predictions;
    return _predictions.where((p) {
      final risk = p['risk_category']?.toString().toLowerCase() ?? '';
      if (_filter == 'high') return risk == 'high';
      if (_filter == 'moderate') return risk == 'moderate';
      if (_filter == 'low') return risk == 'low';
      return true;
    }).toList();
  }

  Future<void> _exportPrediction(Map<String, dynamic> prediction) async {
    try {
      await PdfService.exportPrediction(prediction);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF report exported successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export: $e'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  String _formatDate(String dateTimeStr) {
    try {
      final date = DateTime.parse(dateTimeStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateTimeStr;
    }
  }

  String _getRiskColor(String category) {
    switch (category.toLowerCase()) {
      case 'high':
        return '#C97C5D';
      case 'moderate':
        return '#B89B5E';
      case 'low':
        return '#4CAF50';
      default:
        return '#888888';
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text(
          'Diagnostic History',
          style: TextStyle(
            fontSize: r.fs(18),
            fontWeight: FontWeight.w800,
            color: t.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: t.textPrimary,
      ),
      body: RefreshIndicator(
        color: AppColors.sageGreen,
        backgroundColor: t.surface,
        onRefresh: _fetchHistory,
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
                        horizontal: r.wp(16),
                        vertical: r.sp(6),
                      ),
                      child: Wrap(
                        spacing: r.wp(8),
                        runSpacing: r.sp(8),
                        alignment: WrapAlignment.center,
                        children: [
                          _FilterChip(
                            label: 'All',
                            value: 'all',
                            current: _filter,
                            onSelected: (v) => setState(() => _filter = v),
                          ),
                          _FilterChip(
                            label: 'High',
                            value: 'high',
                            current: _filter,
                            onSelected: (v) => setState(() => _filter = v),
                          ),
                          _FilterChip(
                            label: 'Moderate',
                            value: 'moderate',
                            current: _filter,
                            onSelected: (v) => setState(() => _filter = v),
                          ),
                          _FilterChip(
                            label: 'Low',
                            value: 'low',
                            current: _filter,
                            onSelected: (v) => setState(() => _filter = v),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: r.sp(10)),
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.sageGreen),
                              ),
                            )
                          : _error != null
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.error_outline_rounded,
                                        size: r.wp(48),
                                        color: Colors.red.shade400,
                                      ),
                                      SizedBox(height: r.sp(16)),
                                      Text(
                                        _error!,
                                        style: TextStyle(
                                          color: Colors.red.shade400,
                                          fontSize: r.fs(13),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              : _filteredPredictions.isEmpty
                                  ? Center(
                                      child: Text(
                                        'No diagnostic data recorded.',
                                        style: TextStyle(
                                          color: t.textMuted,
                                          fontSize: r.fs(13),
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      physics: const AlwaysScrollableScrollPhysics(),
                                      padding: EdgeInsets.fromLTRB(
                                        r.wp(16),
                                        0,
                                        r.wp(16),
                                        r.sp(100),
                                      ),
                                      itemCount: _filteredPredictions.length,
                                      itemBuilder: (context, index) {
                                        final prediction = _filteredPredictions[index];
                                        final patient = prediction['patient'] ?? {};
                                        final riskCategory = prediction['risk_category'] ?? 'unknown';
                                        final riskScore = prediction['risk_score'] ?? 0.0;
                                        final hexColor = _getRiskColor(riskCategory);
                                        final categoryColor = Color(int.parse(hexColor.substring(1, 7), radix: 16));

                                        return _buildPredictionCard(
                                          prediction,
                                          patient,
                                          riskCategory,
                                          riskScore,
                                          categoryColor,
                                          r,
                                          t,
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

  Widget _buildPredictionCard(
    Map<String, dynamic> prediction,
    Map<String, dynamic> patient,
    String riskCategory,
    double riskScore,
    Color categoryColor,
    Responsive r,
    AppThemeTokens t,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: EdgeInsets.only(bottom: r.sp(12)),
      padding: EdgeInsets.all(r.sp(14)),
      decoration: BoxDecoration(
        color: t.card.withOpacity(t.isDark ? 0.4 : 1.0),
        borderRadius: BorderRadius.circular(r.sp(16)),
        border: Border.all(color: t.border.withOpacity(0.7)),
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
                  patient['name'] ?? 'Anonymous Patient',
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: r.fs(14),
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _exportPrediction(prediction),
                  child: Container(
                    padding: EdgeInsets.all(r.sp(8)),
                    decoration: BoxDecoration(
                      color: AppColors.sageGreen.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: AppColors.sageGreen,
                      size: r.sp(20),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: r.sp(6)),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: r.wp(10), vertical: r.sp(4)),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(r.sp(8)),
                ),
                child: Text(
                  riskCategory.toString().toUpperCase(),
                  style: TextStyle(
                    color: categoryColor,
                    fontSize: r.fs(10),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: r.wp(12)),
              Text(
                'Index Value: ${(riskScore * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: t.textMuted,
                  fontSize: r.fs(12),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(prediction['created_at'] ?? ''),
                style: TextStyle(
                  color: t.textMuted.withOpacity(0.7),
                  fontSize: r.fs(11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onSelected;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = current == value;
    final t = AppThemeTokens.of(context);
    final r = Responsive.of(context);

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: r.fs(12),
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      backgroundColor: t.card.withOpacity(0.5),
      selectedColor: AppColors.sageGreen.withOpacity(0.15),
      side: BorderSide(
        color: isSelected ? AppColors.sageGreen : t.border.withOpacity(0.5),
        width: 1.5,
      ),
      padding: EdgeInsets.symmetric(horizontal: r.wp(12), vertical: r.sp(4)),
      shape: StadiumBorder(
        side: BorderSide(
          color: isSelected ? AppColors.sageGreen : Colors.transparent,
        ),
      ),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.sageGreen : t.textPrimary,
      ),
    );
  }
}