// lib/screens/assistant_patients_screen.dart
import 'package:flutter/material.dart';
import '../services/token_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_utils.dart';

class AssistantPatientsScreen extends StatefulWidget {
  const AssistantPatientsScreen({super.key});

  @override
  State<AssistantPatientsScreen> createState() => _AssistantPatientsScreenState();
}

class _AssistantPatientsScreenState extends State<AssistantPatientsScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _patients = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _error;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Map<String, dynamic>? _assignedDoctor;

  @override
  void initState() {
    super.initState();
    _fetchPatients();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchPatients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await TokenService.getToken();
      if (token != null) {
        try {
          final doctorResponse = await ApiService.getAssignedDoctor(token);
          setState(() {
            _assignedDoctor = doctorResponse;
          });
        } catch (e) {
          print('Error getting assigned doctor: $e');
        }

        final response = await ApiService.getPatients(
          token: token,
          search: _searchQuery.isEmpty ? null : _searchQuery,
        );

        final patients = response['patients'] ?? [];
        setState(() {
          _patients = patients;
          _isLoading = false;
          _error = null;
        });
      } else {
        setState(() {
          _error = 'No authentication token found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load patients: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshPatients() async {
    await _fetchPatients();
  }

  Future<void> _addPatient() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const _PatientFormDialog(isEditing: false),
    );
    if (result == true) {
      _refreshPatients();
    }
  }

  Future<void> _editPatient(Map<String, dynamic> patient) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _PatientFormDialog(
        isEditing: true,
        patient: patient,
      ),
    );
    if (result == true) {
      _refreshPatients();
    }
  }

  Future<void> _deletePatient(Map<String, dynamic> patient) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Patient'),
        content: Text(
          'Are you sure you want to delete ${patient['first_name']} ${patient['last_name']}?',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      setState(() => _isLoading = true);
      try {
        final token = await TokenService.getToken();
        if (token != null) {
          await ApiService.deletePatient(
            token: token,
            patientId: patient['id'],
          );
          await _refreshPatients();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Patient deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting patient: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(r.sp(6)),
              decoration: BoxDecoration(
                color: AppColors.sageGreen,
                borderRadius: BorderRadius.circular(r.sp(10)),
              ),
              child: Icon(
                Icons.people_alt_rounded,
                color: Colors.white,
                size: r.sp(18),
              ),
            ),
            SizedBox(width: r.wp(8)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Patients Directory',
                  style: TextStyle(
                    fontSize: r.fs(18),
                    fontWeight: FontWeight.w800,
                    color: t.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                if (_assignedDoctor != null &&
                    _assignedDoctor!.containsKey('first_name') &&
                    _assignedDoctor!['first_name'] != 'No')
                  Text(
                    'Working with: Dr. ${_assignedDoctor!['first_name']} ${_assignedDoctor!['last_name']}',
                    style: TextStyle(
                      fontSize: r.fs(10),
                      color: t.textMuted,
                    ),
                  ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: t.textPrimary,
        actions: [
          Container(
            margin: EdgeInsets.only(right: r.wp(8)),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _addPatient,
                child: Container(
                  padding: EdgeInsets.all(r.sp(8)),
                  decoration: BoxDecoration(
                    color: AppColors.sageGreen,
                    borderRadius: BorderRadius.circular(r.sp(12)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.sageGreen.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: r.sp(20),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.sageGreen,
        backgroundColor: t.surface,
        onRefresh: _refreshPatients,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWeb = constraints.maxWidth > 600;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWeb ? 1200 : double.infinity),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(r.wp(16), r.sp(6), r.wp(16), r.sp(14)),
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: r.fs(13),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search patients by name...',
                            hintStyle: TextStyle(
                              color: t.textMuted.withOpacity(0.7),
                              fontSize: r.fs(13),
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: AppColors.sageGreen,
                              size: r.sp(20),
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear_rounded,
                                      color: t.textMuted,
                                      size: r.sp(18),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                      _refreshPatients();
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: t.card,
                            contentPadding: EdgeInsets.symmetric(vertical: r.sp(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(r.sp(16)),
                              borderSide: BorderSide(color: t.border.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(r.sp(16)),
                              borderSide: const BorderSide(color: AppColors.sageGreen, width: 2),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                            _refreshPatients();
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: _isLoading
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: r.sp(50),
                                    height: r.sp(50),
                                    child: const CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.sageGreen),
                                      strokeWidth: 3,
                                    ),
                                  ),
                                  SizedBox(height: r.sp(16)),
                                  Text(
                                    'Loading patients...',
                                    style: TextStyle(
                                      color: t.textMuted,
                                      fontSize: r.fs(12),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _error != null
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(r.sp(20)),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.error_outline_rounded,
                                          size: r.sp(44),
                                          color: Colors.orange.shade300,
                                        ),
                                      ),
                                      SizedBox(height: r.sp(16)),
                                      Text(
                                        'Error Loading Patients',
                                        style: TextStyle(
                                          color: t.textPrimary,
                                          fontSize: r.fs(16),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(height: r.sp(12)),
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: r.wp(20)),
                                        child: Text(
                                          _error!,
                                          style: TextStyle(
                                            color: t.textMuted,
                                            fontSize: r.fs(12),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      SizedBox(height: r.sp(20)),
                                      ElevatedButton.icon(
                                        onPressed: _refreshPatients,
                                        icon: Icon(Icons.refresh_rounded, size: r.sp(16)),
                                        label: const Text('Retry'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.sageGreen,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: r.wp(16),
                                            vertical: r.sp(10),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(r.sp(12)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : _patients.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(r.sp(20)),
                                            decoration: BoxDecoration(
                                              color: t.card,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.medical_information_rounded,
                                              size: r.wp(40),
                                              color: t.textMuted.withOpacity(0.3),
                                            ),
                                          ),
                                          SizedBox(height: r.sp(16)),
                                          Text(
                                            'No Patients Found',
                                            style: TextStyle(
                                              color: t.textMuted,
                                              fontSize: r.fs(16),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: r.sp(8)),
                                          Padding(
                                            padding: EdgeInsets.symmetric(horizontal: r.wp(32)),
                                            child: Text(
                                              _searchQuery.isEmpty
                                                  ? 'No patients have been added to this doctor yet.\nTap the + button to add a patient.'
                                                  : 'No patients match your search criteria.',
                                              style: TextStyle(
                                                color: t.textMuted.withOpacity(0.7),
                                                fontSize: r.fs(12),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          if (_searchQuery.isNotEmpty) ...[
                                            SizedBox(height: r.sp(20)),
                                            OutlinedButton.icon(
                                              onPressed: () {
                                                setState(() {
                                                  _searchQuery = '';
                                                });
                                                _refreshPatients();
                                              },
                                              icon: Icon(Icons.clear_rounded, size: r.sp(16)),
                                              label: const Text('Clear Search'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppColors.sageGreen,
                                                side: const BorderSide(color: AppColors.sageGreen),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(r.sp(10)),
                                                ),
                                              ),
                                            ),
                                          ],
                                          SizedBox(height: r.sp(20)),
                                          ElevatedButton.icon(
                                            onPressed: _addPatient,
                                            icon: Icon(Icons.add_rounded, size: r.sp(16)),
                                            label: const Text('Add First Patient'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.sageGreen,
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.symmetric(
                                                horizontal: r.wp(20),
                                                vertical: r.sp(12),
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(r.sp(12)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : FadeTransition(
                                      opacity: _fadeAnimation,
                                      child: ListView.builder(
                                        physics: const AlwaysScrollableScrollPhysics(),
                                        padding: EdgeInsets.fromLTRB(
                                          r.wp(16),
                                          0,
                                          r.wp(16),
                                          r.sp(100),
                                        ),
                                        itemCount: _patients.length,
                                        itemBuilder: (context, index) {
                                          final patient = _patients[index];
                                          final String fullName =
                                              '${patient['first_name'] ?? ''} ${patient['last_name'] ?? ''}'.trim();
                                          final String firstName = patient['first_name'] ?? 'P';
                                          final String displayName =
                                              fullName.isNotEmpty ? fullName : 'Unknown';

                                          return _buildPatientCard(
                                            patient,
                                            displayName,
                                            firstName,
                                            index,
                                            r,
                                            t,
                                          );
                                        },
                                      ),
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

  Widget _buildPatientCard(
    Map<String, dynamic> patient,
    String displayName,
    String firstName,
    int index,
    Responsive r,
    AppThemeTokens t,
  ) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: r.sp(12)),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(r.sp(18)),
          border: Border.all(color: t.border.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _editPatient(patient),
            borderRadius: BorderRadius.circular(r.sp(18)),
            child: Padding(
              padding: EdgeInsets.all(r.sp(12)),
              child: Row(
                children: [
                  Container(
                    width: r.sp(44),
                    height: r.sp(44),
                    decoration: BoxDecoration(
                      color: AppColors.sageGreen,
                      borderRadius: BorderRadius.circular(r.sp(14)),
                    ),
                    child: Center(
                      child: Text(
                        firstName.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: r.fs(18),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: r.wp(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: r.fs(15),
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: r.sp(4)),
                        Row(
                          children: [
                            Icon(
                              Icons.cake_rounded,
                              size: r.sp(12),
                              color: t.textMuted.withOpacity(0.7),
                            ),
                            SizedBox(width: r.sp(4)),
                            Flexible(
                              child: Text(
                                'DOB: ${patient['date_of_birth'] ?? 'N/A'}',
                                style: TextStyle(
                                  color: t.textMuted,
                                  fontSize: r.fs(11),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: r.sp(8)),
                            Icon(
                              Icons.people_rounded,
                              size: r.sp(12),
                              color: t.textMuted.withOpacity(0.7),
                            ),
                            SizedBox(width: r.sp(4)),
                            Flexible(
                              child: Text(
                                patient['gender'] ?? 'N/A',
                                style: TextStyle(
                                  color: t.textMuted,
                                  fontSize: r.fs(11),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.edit_note_rounded,
                          color: AppColors.sageGreen,
                          size: r.sp(20),
                        ),
                        onPressed: () => _editPatient(patient),
                        tooltip: 'Edit Patient',
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: r.sp(32),
                          minHeight: r.sp(32),
                        ),
                      ),
                      SizedBox(width: r.sp(4)),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.red.shade300,
                          size: r.sp(20),
                        ),
                        onPressed: () => _deletePatient(patient),
                        tooltip: 'Delete Patient',
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: r.sp(32),
                          minHeight: r.sp(32),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Patient Form Dialog (unchanged logic, only UI improvements)
class _PatientFormDialog extends StatefulWidget {
  final bool isEditing;
  final Map<String, dynamic>? patient;

  const _PatientFormDialog({required this.isEditing, this.patient});

  @override
  State<_PatientFormDialog> createState() => _PatientFormDialogState();
}

class _PatientFormDialogState extends State<_PatientFormDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _notesController;
  String _gender = 'Male';
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.patient != null) {
      final fullName =
          '${widget.patient!['first_name'] ?? ''} ${widget.patient!['last_name'] ?? ''}'.trim();
      _nameController = TextEditingController(text: fullName);
      _ageController =
          TextEditingController(text: _dateOfBirthToAge(widget.patient!['date_of_birth']));
      _notesController = TextEditingController(text: widget.patient!['notes']);
      _gender = widget.patient!['gender'] ?? 'Male';
    } else {
      _nameController = TextEditingController();
      _ageController = TextEditingController();
      _notesController = TextEditingController();
      _gender = 'Male';
    }

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _notesController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String _dateOfBirthToAge(String? dateOfBirth) {
    if (dateOfBirth == null || dateOfBirth.isEmpty) return '';
    try {
      final dob = DateTime.parse(dateOfBirth);
      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      return age.toString();
    } catch (e) {
      return '';
    }
  }

  String _formatAgeToDateOfBirth(String ageStr) {
    try {
      final int age = int.parse(ageStr);
      final DateTime now = DateTime.now();
      final DateTime dateOfBirth = DateTime(now.year - age, now.month, now.day);
      return dateOfBirth.toIso8601String().split('T').first;
    } catch (e) {
      return DateTime.now().toIso8601String().split('T').first;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final fullName = _nameController.text.trim();
    final List<String> nameParts = fullName.split(' ');
    final String firstName = nameParts.first;
    final String lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    if (firstName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid name'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        if (widget.isEditing) {
          await ApiService.updatePatient(
            token: token,
            patientId: widget.patient!['id'],
            firstName: firstName,
            lastName: lastName,
            dateOfBirth: _formatAgeToDateOfBirth(_ageController.text),
            gender: _gender,
            notes: _notesController.text,
          );
        } else {
          await ApiService.createPatient(
            token: token,
            firstName: firstName,
            lastName: lastName,
            dateOfBirth: _formatAgeToDateOfBirth(_ageController.text),
            gender: _gender,
            notes: _notesController.text,
          );
        }
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.sp(24))),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxWidth: r.wp(90)),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(r.sp(20)),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(r.sp(10)),
                          decoration: BoxDecoration(
                            color: AppColors.sageGreen,
                            borderRadius: BorderRadius.circular(r.sp(14)),
                          ),
                          child: Icon(
                            widget.isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
                            color: Colors.white,
                            size: r.sp(20),
                          ),
                        ),
                        SizedBox(width: r.sp(12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.isEditing ? 'Edit Patient' : 'New Patient',
                                style: TextStyle(
                                  color: t.textPrimary,
                                  fontSize: r.fs(18),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                widget.isEditing ? 'Modify patient information' : 'Add patient to directory',
                                style: TextStyle(
                                  color: t.textMuted,
                                  fontSize: r.fs(11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: r.sp(20)),
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: t.textPrimary, fontSize: r.fs(14)),
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        labelStyle: TextStyle(color: t.textMuted, fontSize: r.fs(12)),
                        prefixIcon: Icon(Icons.person_rounded, color: AppColors.sageGreen, size: r.sp(20)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(r.sp(14)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(r.sp(14)),
                          borderSide: BorderSide(color: t.border.withOpacity(0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(r.sp(14)),
                          borderSide: const BorderSide(color: AppColors.sageGreen, width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: r.sp(16), vertical: r.sp(14)),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required field' : null,
                    ),
                    SizedBox(height: r.sp(16)),
                    TextFormField(
                      controller: _ageController,
                      style: TextStyle(color: t.textPrimary, fontSize: r.fs(14)),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Age',
                        labelStyle: TextStyle(color: t.textMuted, fontSize: r.fs(12)),
                        prefixIcon: Icon(Icons.cake_rounded, color: AppColors.sageGreen, size: r.sp(20)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(r.sp(14)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(r.sp(14)),
                          borderSide: BorderSide(color: t.border.withOpacity(0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(r.sp(14)),
                          borderSide: const BorderSide(color: AppColors.sageGreen, width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: r.sp(16), vertical: r.sp(14)),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required field' : null,
                    ),
                    SizedBox(height: r.sp(16)),
                    DropdownButtonFormField<String>(
                      value: _gender,
                      dropdownColor: t.surface,
                      style: TextStyle(color: t.textPrimary, fontSize: r.fs(14)),
                      decoration: InputDecoration(
                        labelText: 'Gender',
                        labelStyle: TextStyle(color: t.textMuted, fontSize: r.fs(12)),
                        prefixIcon: Icon(Icons.people_rounded, color: AppColors.sageGreen, size: r.sp(20)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(r.sp(14)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(r.sp(14)),
                          borderSide: BorderSide(color: t.border.withOpacity(0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(r.sp(14)),
                          borderSide: const BorderSide(color: AppColors.sageGreen, width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: r.sp(16), vertical: r.sp(2)),
                      ),
                      items: ['Male', 'Female', 'Other']
                          .map((g) => DropdownMenuItem(
                                value: g,
                                child: Text(g, style: TextStyle(fontSize: r.fs(14))),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _gender = v!),
                    ),
                    SizedBox(height: r.sp(16)),
                    TextFormField(
                      controller: _notesController,
                      style: TextStyle(color: t.textPrimary, fontSize: r.fs(14)),
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        labelStyle: TextStyle(color: t.textMuted, fontSize: r.fs(12)),
                        prefixIcon: Icon(Icons.note_rounded, color: AppColors.sageGreen, size: r.sp(20)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(r.sp(14)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(r.sp(14)),
                          borderSide: BorderSide(color: t.border.withOpacity(0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(r.sp(14)),
                          borderSide: const BorderSide(color: AppColors.sageGreen, width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: r.sp(16), vertical: r.sp(14)),
                      ),
                      maxLines: 3,
                    ),
                    SizedBox(height: r.sp(24)),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: t.textMuted,
                              side: BorderSide(color: t.border),
                              padding: EdgeInsets.symmetric(vertical: r.sp(14)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(r.sp(14)),
                              ),
                            ),
                            child: Text('Cancel', style: TextStyle(fontSize: r.fs(14))),
                          ),
                        ),
                        SizedBox(width: r.sp(12)),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.sageGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(vertical: r.sp(14)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(r.sp(14)),
                              ),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: r.sp(20),
                                    width: r.sp(20),
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : Text(
                                    'Save Patient',
                                    style: TextStyle(
                                      fontSize: r.fs(14),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}