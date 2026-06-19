import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/token_service.dart';
import '../services/patient_service.dart';
import '../utils/responsive_utils.dart';
import '../utils/scaled_viewport.dart';
import 'prediction_screen.dart';
import 'package:intl/intl.dart';

/// Screens at or above this width are treated as desktop/web layouts:
/// a centered dialog instead of a bottom sheet, a multi-column patient
/// grid instead of a single list, and one inline "Add Patient" button
/// instead of a floating action button.
const double kWebBreakpoint = 760;

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  List<dynamic> _patients = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _isSaving = false;

  final _formKey = GlobalKey<FormState>();
  final _searchCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _genderCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _medicalHistoryCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final List<String> _genderOptions = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _dobCtrl.dispose();
    _genderCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _medicalHistoryCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ───────────────────────── Data layer (unchanged) ─────────────────────────

  Future<void> _loadPatients() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await TokenService.getToken();
      if (token != null) {
        final patients = await PatientService.getPatients(
          token: token,
          search: _searchQuery.isEmpty ? null : _searchQuery,
        );
        setState(() {
          _patients = patients;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading patients: $e')),
      );
    }
  }

  Future<void> _addPatient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final token = await TokenService.getToken();
      if (token != null) {
        DateTime? dob;
        if (_dobCtrl.text.isNotEmpty) {
          dob = DateTime.parse(_dobCtrl.text);
        }

        await PatientService.createPatient(
          token: token,
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          dateOfBirth: dob?.toIso8601String().split('T')[0],
          gender: _genderCtrl.text,
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          medicalHistory: _medicalHistoryCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
        );

        Navigator.pop(context);
        await _loadPatients();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient added successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _updatePatient(int patientId) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final token = await TokenService.getToken();
      if (token != null) {
        DateTime? dob;
        if (_dobCtrl.text.isNotEmpty) {
          dob = DateTime.parse(_dobCtrl.text);
        }

        await PatientService.updatePatient(
          token: token,
          patientId: patientId,
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          dateOfBirth: dob?.toIso8601String().split('T')[0],
          gender: _genderCtrl.text,
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          medicalHistory: _medicalHistoryCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
        );

        Navigator.pop(context);
        await _loadPatients();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient updated successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _deletePatient(Map<String, dynamic> patient) async {
    final t = AppThemeTokens.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: t.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.delete_outline_rounded,
              color: Colors.red, size: 26),
        ),
        title: const Text('Delete Patient'),
        content: Text(
          'Are you sure you want to delete ${patient['first_name']} ${patient['last_name']}?\n\nThis will also delete all predictions associated with this patient.',
          textAlign: TextAlign.center,
          style: const TextStyle(height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: t.textPrimary,
              side: BorderSide(color: t.border),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await TokenService.getToken();
      if (token != null) {
        await PatientService.deletePatient(
          token: token,
          patientId: patient['id'],
        );

        await _loadPatients();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient deleted successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting patient: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  int _calculateAge(String? dateOfBirth) {
    if (dateOfBirth == null || dateOfBirth.isEmpty) return 0;
    try {
      final dob = DateTime.parse(dateOfBirth);
      final today = DateTime.now();
      int age = today.year - dob.year;
      if (today.month < dob.month ||
          (today.month == dob.month && today.day < dob.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 50)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobCtrl.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  // ───────────────────── Adaptive modal: dialog on web, sheet on mobile ─────────────────────

  /// Shows [contentBuilder]'s widget as a centered, rounded dialog on
  /// wide/web layouts (where a slide-up sheet looks out of place), and as
  /// a draggable bottom sheet on narrow/mobile layouts. The scroll
  /// controller passed to [contentBuilder] is null on web — there the
  /// dialog grows to fit its content instead of being drag-resizable.
  Future<T?> _showAdaptiveSheet<T>({
    required Widget Function(BuildContext context, ScrollController? controller)
        contentBuilder,
    double webMaxWidth = 560,
  }) {
    final t = AppThemeTokens.of(context);
    final isWeb = MediaQuery.of(context).size.width >= kWebBreakpoint;

    if (isWeb) {
      return showDialog<T>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.45),
        builder: (dialogCtx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: webMaxWidth,
              maxHeight: MediaQuery.of(dialogCtx).size.height * 0.88,
            ),
            child: Material(
              color: t.bg,
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: contentBuilder(dialogCtx, null),
            ),
          ),
        ),
      );
    }

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: t.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: contentBuilder(sheetCtx, controller),
        ),
      ),
    );
  }

  Widget _sheetHeader(String title, {required bool isWeb}) {
    final t = AppThemeTokens.of(context);
    return Column(
      children: [
        if (!isWeb)
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 2),
            child: Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: t.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, isWeb ? 22 : 14, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: t.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: t.textMuted, size: 22),
                splashRadius: 20,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────── Add / Edit patient form ─────────────────────────

  void _showAddPatientDialog() {
    _firstNameCtrl.clear();
    _lastNameCtrl.clear();
    _dobCtrl.clear();
    _genderCtrl.clear();
    _phoneCtrl.clear();
    _emailCtrl.clear();
    _addressCtrl.clear();
    _medicalHistoryCtrl.clear();
    _notesCtrl.clear();
    _openPatientFormSheet(isEdit: false);
  }

  void _showEditPatientDialog(Map<String, dynamic> patient) {
    _firstNameCtrl.text = patient['first_name'] ?? '';
    _lastNameCtrl.text = patient['last_name'] ?? '';
    _dobCtrl.text = patient['date_of_birth'] ?? '';
    _genderCtrl.text = patient['gender'] ?? '';
    _phoneCtrl.text = patient['phone'] ?? '';
    _emailCtrl.text = patient['email'] ?? '';
    _addressCtrl.text = patient['address'] ?? '';
    _medicalHistoryCtrl.text = patient['medical_history'] ?? '';
    _notesCtrl.text = patient['notes'] ?? '';
    _openPatientFormSheet(isEdit: true, patient: patient);
  }

  void _openPatientFormSheet({required bool isEdit, Map<String, dynamic>? patient}) {
    _showAdaptiveSheet(
      contentBuilder: (context, controller) {
        final isWeb = controller == null;
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Column(
              children: [
                _sheetHeader(isEdit ? 'Edit Patient' : 'Add New Patient',
                    isWeb: isWeb),
                Expanded(
                  child: SingleChildScrollView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _responsiveFieldRow(
                            isWeb,
                            _buildTextField(_firstNameCtrl, 'First Name',
                                Icons.person_outline,
                                required: true),
                            _buildTextField(_lastNameCtrl, 'Last Name',
                                Icons.person_outline,
                                required: true),
                          ),
                          const SizedBox(height: 14),
                          _buildDateOfBirthField(),
                          const SizedBox(height: 14),
                          _buildGenderSelector(setLocalState),
                          const SizedBox(height: 14),
                          _responsiveFieldRow(
                            isWeb,
                            _buildTextField(_phoneCtrl, 'Phone',
                                Icons.phone_outlined,
                                type: TextInputType.phone),
                            _buildTextField(_emailCtrl, 'Email',
                                Icons.email_outlined,
                                type: TextInputType.emailAddress),
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                              _addressCtrl, 'Address', Icons.location_on_outlined),
                          const SizedBox(height: 14),
                          _buildTextField(_medicalHistoryCtrl, 'Medical History',
                              Icons.history,
                              maxLines: 3),
                          const SizedBox(height: 14),
                          _buildTextField(
                              _notesCtrl, 'Notes', Icons.note_outlined,
                              maxLines: 2),
                          const SizedBox(height: 26),
                          if (isEdit)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.sageGreen,
                                      side: const BorderSide(
                                          color: AppColors.sageGreen),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 15),
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _updatePatient(patient!['id']),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.sageGreen,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 15),
                                    ),
                                    child: const Text('Save Changes'),
                                  ),
                                ),
                              ],
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _addPatient,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.sageGreen,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Add Patient',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700),
                                      ),
                              ),
                            ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// On web, lays two fields side by side; on mobile, stacks them.
  Widget _responsiveFieldRow(bool isWeb, Widget first, Widget second) {
    if (isWeb) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          const SizedBox(width: 14),
          Expanded(child: second),
        ],
      );
    }
    return Column(
      children: [first, const SizedBox(height: 14), second],
    );
  }

  Widget _buildGenderSelector(void Function(VoidCallback) setLocalState) {
    final t = AppThemeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: TextStyle(
              fontSize: 12.5, color: t.textMuted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: _genderOptions.map((g) {
            final selected = _genderCtrl.text == g;
            return Expanded(
              child: Padding(
                padding:
                    EdgeInsets.only(right: g != _genderOptions.last ? 10 : 0),
                child: GestureDetector(
                  onTap: () => setLocalState(() => _genderCtrl.text = g),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.sageGreen : t.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: selected ? AppColors.sageGreen : t.border),
                    ),
                    child: Text(
                      g,
                      style: TextStyle(
                        color: selected ? Colors.white : t.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDateOfBirthField() {
    final t = AppThemeTokens.of(context);

    return GestureDetector(
      onTap: _selectDateOfBirth,
      child: AbsorbPointer(
        child: TextFormField(
          controller: _dobCtrl,
          style: TextStyle(color: t.textPrimary),
          decoration: InputDecoration(
            hintText: 'Date of Birth (YYYY-MM-DD)',
            hintStyle: TextStyle(color: t.textMuted),
            prefixIcon: Icon(Icons.calendar_today, color: AppColors.sageGreen),
            suffixIcon:
                Icon(Icons.arrow_drop_down, color: AppColors.sageGreen),
            filled: true,
            fillColor: t.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.sageGreen),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController c, String label, IconData icon,
      {bool required = false,
      int maxLines = 1,
      TextInputType type = TextInputType.text}) {
    final t = AppThemeTokens.of(context);

    return TextFormField(
      controller: c,
      keyboardType: type,
      maxLines: maxLines,
      style: TextStyle(color: t.textPrimary),
      validator: required
          ? (value) =>
              value == null || value.isEmpty ? '$label is required' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: t.textMuted),
        prefixIcon: Icon(icon, color: AppColors.sageGreen),
        filled: true,
        fillColor: t.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.sageGreen),
        ),
      ),
    );
  }

  // ───────────────────────── Patient details ─────────────────────────

  void _showPatientDetails(Map<String, dynamic> patient) {
    final age = _calculateAge(patient['date_of_birth']);

    _showAdaptiveSheet(
      webMaxWidth: 520,
      contentBuilder: (context, controller) {
        final isWeb = controller == null;
        final t = AppThemeTokens.of(context);
        final gender = (patient['gender'] ?? '').toString().toLowerCase();
        final avatarColor = gender == 'male'
            ? const Color(0xFF5B8FDB)
            : gender == 'female'
                ? const Color(0xFFD97CAC)
                : AppColors.sageGreen;

        return Column(
          children: [
            _sheetHeader('Patient Details', isWeb: isWeb),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            avatarColor.withOpacity(0.18),
                            avatarColor.withOpacity(0.05),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: avatarColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: avatarColor.withOpacity(0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                '${(patient['first_name'] ?? '').isNotEmpty ? patient['first_name'][0] : ''}${(patient['last_name'] ?? '').isNotEmpty ? patient['last_name'][0] : ''}'
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${patient['first_name']} ${patient['last_name']}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: t.textPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                          if (age > 0 ||
                              (patient['gender'] ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              [
                                if (age > 0) '$age years',
                                if ((patient['gender'] ?? '').isNotEmpty)
                                  patient['gender'],
                              ].join(' · '),
                              style: TextStyle(fontSize: 13, color: t.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader('Patient Information', t),
                    const SizedBox(height: 12),
                    _DetailRow(
                        label: 'Patient ID', value: '#${patient['id']}', t: t),
                    _DetailRow(
                        label: 'Full Name',
                        value:
                            '${patient['first_name']} ${patient['last_name']}',
                        t: t),
                    _DetailRow(
                        label: 'Age',
                        value: age > 0 ? '$age years' : 'Not set',
                        t: t),
                    _DetailRow(
                        label: 'Gender',
                        value: patient['gender'] ?? 'Not set',
                        t: t),
                    _DetailRow(
                        label: 'Phone', value: patient['phone'] ?? 'Not set', t: t),
                    _DetailRow(
                        label: 'Email', value: patient['email'] ?? 'Not set', t: t),
                    _DetailRow(
                        label: 'Address',
                        value: patient['address'] ?? 'Not set',
                        t: t),
                    if (patient['date_of_birth'] != null)
                      _DetailRow(
                        label: 'Date of Birth',
                        value: patient['date_of_birth'],
                        t: t,
                      ),
                    if (patient['medical_history'] != null &&
                        patient['medical_history'].isNotEmpty)
                      _DetailRow(
                          label: 'Medical History',
                          value: patient['medical_history'],
                          isLong: true,
                          t: t),
                    if (patient['notes'] != null &&
                        patient['notes'].isNotEmpty)
                      _DetailRow(
                          label: 'Notes',
                          value: patient['notes'],
                          isLong: true,
                          t: t),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PredictionScreen(
                                prefillPatient: {
                                  'id': patient['id'],
                                  'first_name': patient['first_name'],
                                  'last_name': patient['last_name'],
                                  'gender': patient['gender'],
                                  'date_of_birth': patient['date_of_birth'],
                                },
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.auto_graph_rounded, size: 18),
                        label: const Text('New Prediction',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.sageGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showEditPatientDialog(patient);
                            },
                            icon: const Icon(Icons.edit_outlined, size: 17),
                            label: const Text('Edit'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.sageGreen,
                              side: const BorderSide(
                                  color: AppColors.sageGreen),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _deletePatient(patient);
                            },
                            icon:
                                const Icon(Icons.delete_outline_rounded, size: 17),
                            label: const Text('Delete'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ───────────────────────── Search field ─────────────────────────

  Widget _buildSearchField(AppThemeTokens t) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
        boxShadow: [
          BoxShadow(
            color: t.textPrimary.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (value) {
          _searchQuery = value;
          _loadPatients();
        },
        style: TextStyle(color: t.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search by name...',
          hintStyle: TextStyle(color: t.textMuted),
          prefixIcon:
              Icon(Icons.search_rounded, color: t.textMuted, size: 20),
          suffixIcon: _searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close_rounded, color: t.textMuted, size: 18),
                  splashRadius: 16,
                  onPressed: () {
                    _searchCtrl.clear();
                    _searchQuery = '';
                    _loadPatients();
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  // ───────────────────────── Empty state ─────────────────────────

  Widget _buildEmptyState(AppThemeTokens t, bool isWeb) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.sageGreen.withOpacity(0.07),
                    shape: BoxShape.circle,
                  ),
                ),
                Icon(
                  Icons.people_outline_rounded,
                  size: 50,
                  color: AppColors.sageGreen.withOpacity(0.5),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              _searchQuery.isEmpty ? 'No patients yet' : 'No patients found',
              style: TextStyle(
                  color: t.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isEmpty
                  ? (isWeb
                      ? 'Use "Add Patient" above to get started.'
                      : 'Tap the + button below to add your first patient.')
                  : 'Try a different search term.',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.textMuted, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Patient list (mobile) & grid (web) ─────────────────────────

  Widget _buildPatientList(AppThemeTokens t) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      itemCount: _patients.length,
      itemBuilder: (context, index) {
        final patient = _patients[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _PatientCard(
            patient: patient,
            age: _calculateAge(patient['date_of_birth']),
            isGrid: false,
            onEdit: () => _showEditPatientDialog(patient),
            onDelete: () => _deletePatient(patient),
            onView: () => _showPatientDetails(patient),
          ),
        );
      },
    );
  }

  Widget _buildPatientGrid(AppThemeTokens t) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        mainAxisExtent: 184,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _patients.length,
      itemBuilder: (context, index) {
        final patient = _patients[index];
        // Each card gets a ScaledViewport so Responsive.of(context) inside
        // it scales against this grid cell's actual width, not the full
        // browser viewport (see scaled_viewport.dart).
        return LayoutBuilder(
          builder: (context, constraints) {
            return ScaledViewport(
              width: constraints.maxWidth,
              child: _PatientCard(
                patient: patient,
                age: _calculateAge(patient['date_of_birth']),
                isGrid: true,
                onEdit: () => _showEditPatientDialog(patient),
                onDelete: () => _deletePatient(patient),
                onView: () => _showPatientDetails(patient),
              ),
            );
          },
        );
      },
    );
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = AppThemeTokens.of(context);
    final isWeb = MediaQuery.of(context).size.width >= kWebBreakpoint;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Patients'),
            const SizedBox(width: 8),
            if (!_isLoading && _patients.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.sageGreen.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_patients.length}',
                  style: TextStyle(
                    color: AppColors.sageGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: t.textPrimary,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWeb ? 1200 : double.infinity),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                isWeb ? 32 : 16, isWeb ? 20 : 4, isWeb ? 32 : 16, isWeb ? 8 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildSearchField(t)),
                    if (isWeb) ...[
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _showAddPatientDialog,
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text('Add Patient'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.sageGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: isWeb ? 20 : 12),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _patients.isEmpty
                          ? _buildEmptyState(t, isWeb)
                          : RefreshIndicator(
                              onRefresh: _loadPatients,
                              color: AppColors.sageGreen,
                              backgroundColor: t.surface,
                              child: isWeb
                                  ? _buildPatientGrid(t)
                                  : _buildPatientList(t),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
      // A single, platform-appropriate way to add a patient: an inline
      // button in the toolbar on web, a FAB on mobile. The old AppBar
      // "Add" button and the empty-state's own button were removed so
      // there's exactly one entry point at a time.
      floatingActionButton: isWeb
          ? null
          : FloatingActionButton(
              onPressed: _showAddPatientDialog,
              backgroundColor: AppColors.sageGreen,
              elevation: 3,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            ),
    );
  }
}

class _PatientCard extends StatefulWidget {
  final Map<String, dynamic> patient;
  final int age;
  final bool isGrid;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onView;

  const _PatientCard({
    required this.patient,
    required this.age,
    required this.isGrid,
    required this.onEdit,
    required this.onDelete,
    required this.onView,
  });

  @override
  State<_PatientCard> createState() => _PatientCardState();
}

class _PatientCardState extends State<_PatientCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeTokens.of(context);
    final r = Responsive.of(context);
    final patient = widget.patient;
    final gender = (patient['gender'] ?? '').toString().toLowerCase();
    final avatarColor = gender == 'male'
        ? const Color(0xFF5B8FDB)
        : gender == 'female'
            ? const Color(0xFFD97CAC)
            : AppColors.sageGreen;
    final firstName = (patient['first_name'] ?? '').toString();
    final lastName = (patient['last_name'] ?? '').toString();
    final initials =
        '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
            .toUpperCase();

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.symmetric(
          horizontal: widget.isGrid ? 16 : 14, vertical: widget.isGrid ? 16 : 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(r.cardRadius),
        border: Border.all(
            color: _hovering ? AppColors.sageGreen.withOpacity(0.45) : t.border),
        boxShadow: _hovering
            ? [
                BoxShadow(
                  color: AppColors.sageGreen.withOpacity(0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : const [],
      ),
      child: widget.isGrid
          ? _gridLayout(t, r, avatarColor, initials, firstName, lastName, gender)
          : _listLayout(t, r, avatarColor, initials, firstName, lastName, gender),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(onTap: widget.onView, child: card),
    );
  }

  Widget _listLayout(AppThemeTokens t, Responsive r, Color avatarColor,
      String initials, String firstName, String lastName, String gender) {
    return Row(
      children: [
        _avatar(avatarColor, initials, 46),
        const SizedBox(width: 12),
        Expanded(
            child:
                _infoColumn(t, r, avatarColor, firstName, lastName, gender)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconActionButton(
              icon: Icons.edit_outlined,
              color: t.textPrimary.withOpacity(0.6),
              onTap: widget.onEdit,
            ),
            const SizedBox(width: 2),
            _IconActionButton(
              icon: Icons.delete_outline_rounded,
              color: Colors.red.withOpacity(0.7),
              onTap: widget.onDelete,
            ),
            const SizedBox(width: 2),
            _IconActionButton(
              icon: Icons.chevron_right_rounded,
              color: AppColors.sageGreen,
              onTap: widget.onView,
            ),
          ],
        ),
      ],
    );
  }

  Widget _gridLayout(AppThemeTokens t, Responsive r, Color avatarColor,
      String initials, String firstName, String lastName, String gender) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(avatarColor, initials, 48),
            const SizedBox(width: 12),
            Expanded(
                child:
                    _infoColumn(t, r, avatarColor, firstName, lastName, gender)),
          ],
        ),
        const Spacer(),
        Container(height: 1, color: t.border),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'View details',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.sageGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _IconActionButton(
              icon: Icons.edit_outlined,
              color: t.textPrimary.withOpacity(0.6),
              onTap: widget.onEdit,
            ),
            const SizedBox(width: 2),
            _IconActionButton(
              icon: Icons.delete_outline_rounded,
              color: Colors.red.withOpacity(0.7),
              onTap: widget.onDelete,
            ),
          ],
        ),
      ],
    );
  }

  Widget _avatar(Color color, String initials, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Center(
        child: Text(
          initials.isNotEmpty ? initials : '?',
          style: TextStyle(
              color: color, fontSize: size * 0.34, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _infoColumn(AppThemeTokens t, Responsive r, Color avatarColor,
      String firstName, String lastName, String gender) {
    final patient = widget.patient;
    final phone = (patient['phone'] ?? '').toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$firstName $lastName',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: r.fs(15),
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Text(
              widget.age > 0 ? '${widget.age} yrs' : 'Age unknown',
              style: TextStyle(fontSize: 12, color: t.textMuted),
            ),
            if (gender.isNotEmpty) ...[
              Text(' · ', style: TextStyle(color: t.textMuted, fontSize: 12)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: avatarColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  patient['gender'],
                  style: TextStyle(
                    fontSize: 11,
                    color: avatarColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (phone.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              phone,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: t.textMuted),
            ),
          ),
      ],
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  final AppThemeTokens t;
  const _SectionHeader(this.text, this.t);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.sageGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLong;
  final AppThemeTokens t;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isLong = false,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: t.textMuted,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}