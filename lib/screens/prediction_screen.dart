import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/token_service.dart';
import '../services/api_service.dart';
import '../services/patient_service.dart';
import '../services/pdf_service.dart';
import '../utils/responsive_utils.dart';
import 'chatbot_screen.dart';

class PredictionScreen extends StatefulWidget {
  final Map<String, dynamic>? prefillPatient;
  const PredictionScreen({super.key, this.prefillPatient});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  final _patientNameCtrl = TextEditingController();
  final _ageCtrl         = TextEditingController();
  final _genderCtrl      = TextEditingController();
  final _cpCtrl          = TextEditingController();
  final _bpCtrl          = TextEditingController();
  final _cholCtrl        = TextEditingController();
  final _fbsCtrl         = TextEditingController();
  final _restEcgCtrl     = TextEditingController();
  final _heartRateCtrl   = TextEditingController();
  final _exangCtrl       = TextEditingController();
  final _oldpeakCtrl     = TextEditingController();
  final _slopeCtrl       = TextEditingController();
  final _dobCtrl         = TextEditingController();

  bool          _isLoading        = false;
  bool          _isLoadingPatients = false;
  String?       _error;
  List<dynamic> _patients          = [];
  int?          _selectedPatientId;

  final List<String> _genderOptions  = ['Male', 'Female'];
  final List<String> _cpOptions      = ['Typical Angina', 'Atypical Angina', 'Non-anginal Pain', 'Asymptomatic'];
  final List<String> _fbsOptions     = ['≤ 120 mg/dl', '> 120 mg/dl'];
  final List<String> _restEcgOptions = ['Normal', 'ST-T Abnormality', 'LV Hypertrophy'];
  final List<String> _exangOptions   = ['No', 'Yes'];
  final List<String> _slopeOptions   = ['Upsloping', 'Flat', 'Downsloping'];

  final Map<String, int> _cpMap      = {'Typical Angina': 0, 'Atypical Angina': 1, 'Non-anginal Pain': 2, 'Asymptomatic': 3};
  final Map<String, int> _fbsMap     = {'≤ 120 mg/dl': 0, '> 120 mg/dl': 1};
  final Map<String, int> _restEcgMap = {'Normal': 0, 'ST-T Abnormality': 1, 'LV Hypertrophy': 2};
  final Map<String, int> _exangMap   = {'No': 0, 'Yes': 1};
  final Map<String, int> _slopeMap   = {'Upsloping': 0, 'Flat': 1, 'Downsloping': 2};

  @override
  void initState() {
    super.initState();
    _loadPatients();
    if (widget.prefillPatient != null) {
      final p = widget.prefillPatient!;
      _selectedPatientId = p['id'];
      _patientNameCtrl.text = '${p['first_name']} ${p['last_name']}';
      if (p['gender'] != null && p['gender'].isNotEmpty) _genderCtrl.text = p['gender'];
      if (p['date_of_birth'] != null && p['date_of_birth'].isNotEmpty) {
        final dob = DateTime.parse(p['date_of_birth']);
        _ageCtrl.text = (DateTime.now().difference(dob).inDays ~/ 365).toString();
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_patientNameCtrl, _ageCtrl, _genderCtrl, _cpCtrl,
        _bpCtrl, _cholCtrl, _fbsCtrl, _restEcgCtrl, _heartRateCtrl,
        _exangCtrl, _oldpeakCtrl, _slopeCtrl, _dobCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDateOfBirth() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 50)),
      firstDate:   DateTime(1900),
      lastDate:    DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobCtrl.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
        _ageCtrl.text = (DateTime.now().difference(picked).inDays ~/ 365).toString();
      });
    }
  }

  Future<void> _loadPatients() async {
    setState(() => _isLoadingPatients = true);
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        final patients = await PatientService.getPatients(token: token, limit: 100);
        setState(() { _patients = patients; _isLoadingPatients = false; });
      }
    } catch (_) { setState(() => _isLoadingPatients = false); }
  }

  void _onPatientSelected(int? patientId) {
    setState(() {
      _selectedPatientId = patientId;
      if (patientId != null) {
        final p = _patients.firstWhere((p) => p['id'] == patientId);
        _patientNameCtrl.text = '${p['first_name']} ${p['last_name']}';
        if (p['date_of_birth'] != null) {
          final dob = DateTime.parse(p['date_of_birth']);
          _ageCtrl.text = (DateTime.now().difference(dob).inDays ~/ 365).toString();
        }
        if (p['gender'] != null && p['gender'].isNotEmpty) _genderCtrl.text = p['gender'];
      } else {
        _patientNameCtrl.clear();
        _ageCtrl.clear();
        _genderCtrl.clear();
      }
    });
  }

  Future<int?> _createPatientFromPrediction() async {
    final name = _patientNameCtrl.text.trim();
    if (name.isEmpty) return null;
    final parts = name.split(' ');
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        final patient = await PatientService.createPatient(
          token:       token,
          firstName:   parts.first,
          lastName:    parts.length > 1 ? parts.sublist(1).join(' ') : '',
          gender:      _genderCtrl.text,
          dateOfBirth: _dobCtrl.text.isEmpty ? null : _dobCtrl.text,
        );
        return patient['id'];
      }
    } catch (_) {}
    return null;
  }

  Future<void> _submitPrediction() async {
    if (_ageCtrl.text.isEmpty || _bpCtrl.text.isEmpty || _cholCtrl.text.isEmpty ||
        _heartRateCtrl.text.isEmpty || _oldpeakCtrl.text.isEmpty ||
        _genderCtrl.text.isEmpty || _cpCtrl.text.isEmpty || _fbsCtrl.text.isEmpty ||
        _restEcgCtrl.text.isEmpty || _exangCtrl.text.isEmpty || _slopeCtrl.text.isEmpty) {
      setState(() => _error = 'Please fill all required fields'); return;
    }
    final age       = int.tryParse(_ageCtrl.text) ?? 0;
    final bp        = int.tryParse(_bpCtrl.text) ?? 0;
    final chol      = int.tryParse(_cholCtrl.text) ?? 0;
    final heartRate = int.tryParse(_heartRateCtrl.text) ?? 0;
    final oldpeak   = double.tryParse(_oldpeakCtrl.text) ?? 0;

    if (age < 1 || age > 120)            { setState(() => _error = 'Age must be 1–120 years'); return; }
    if (bp < 50 || bp > 250)             { setState(() => _error = 'BP must be 50–250 mm Hg'); return; }
    if (chol < 100 || chol > 600)        { setState(() => _error = 'Cholesterol must be 100–600 mg/dl'); return; }
    if (heartRate < 60 || heartRate > 250){ setState(() => _error = 'Heart rate must be 60–250 bpm'); return; }
    if (oldpeak < 0 || oldpeak > 10)     { setState(() => _error = 'ST depression must be 0–10 mm'); return; }

    setState(() { _isLoading = true; _error = null; });

    try {
      final token = await TokenService.getToken();
      if (token != null) {
        int? patientId = _selectedPatientId;
        if (patientId == null && _patientNameCtrl.text.trim().isNotEmpty) {
          patientId = await _createPatientFromPrediction();
        }
        final result = await ApiService.predict(
          token:       token,
          patientId:   patientId,
          patientName: _patientNameCtrl.text.trim().isEmpty ? null : _patientNameCtrl.text.trim(),
          age: age, sex: _genderCtrl.text == 'Male' ? 1 : 0,
          cp: _cpMap[_cpCtrl.text]!, trestbps: bp, chol: chol,
          fbs: _fbsMap[_fbsCtrl.text]!, restecg: _restEcgMap[_restEcgCtrl.text]!,
          thalach: heartRate, exang: _exangMap[_exangCtrl.text]!,
          oldpeak: oldpeak, slope: _slopeMap[_slopeCtrl.text]!,
        );
        if (mounted) {
          final predictionData = {
            'id': result['prediction_id'], 'patient_id': patientId,
            'patient_name': _patientNameCtrl.text.trim(),
            'age': age, 'sex': _genderCtrl.text == 'Male' ? 1 : 0,
            'cp': _cpMap[_cpCtrl.text], 'trestbps': bp, 'chol': chol,
            'fbs': _fbsMap[_fbsCtrl.text], 'restecg': _restEcgMap[_restEcgCtrl.text],
            'thalach': heartRate, 'exang': _exangMap[_exangCtrl.text],
            'oldpeak': oldpeak, 'slope': _slopeMap[_slopeCtrl.text],
            'risk_score': result['risk_score'], 'risk_category': result['risk_category'],
            'has_disease': result['has_disease'],
            'created_at': DateTime.now().toIso8601String(),
          };
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => PredictionResultScreen(
              predictionId:  result['prediction_id'],
              riskScore:     result['risk_score'],
              riskCategory:  result['risk_category'],
              hasDisease:    result['has_disease'],
              patientName:   _patientNameCtrl.text.trim(),
              patientAge:    age,
              patientGender: _genderCtrl.text,
              predictionData: predictionData,
            ),
          ));
        }
      }
    } catch (e) {
      setState(() => _error = 'Prediction failed: ${e.toString().replaceAll('Exception:', '')}');
    } finally { setState(() => _isLoading = false); }
  }


@override
Widget build(BuildContext context) {
  final r = Responsive.of(context);
  final t = AppThemeTokens.of(context);

  return Scaffold(
    backgroundColor: t.bg,
    appBar: AppBar(
      title: Text(
        'New Prediction',
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
    body: LayoutBuilder(
      builder: (context, constraints) {
        final isWeb = constraints.maxWidth > 600;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isWeb ? 800 : double.infinity),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(r.hp),
              child: Column(
                children: [
            // Patient selector
            if (_isLoadingPatients)
              const Center(child: CircularProgressIndicator())
            else
              _buildPatientDropdown(r, t),

            _buildTextField(r, _patientNameCtrl, 'Patient Name (Optional)', Icons.person_outline, t),
            _buildDateOfBirthField(r, t),
            _buildTextField(r, _ageCtrl, 'Age (1–120 years) *', Icons.cake_outlined, t, keyboardType: TextInputType.number),
            _buildDropdown(r, _genderCtrl, 'Gender *', _genderOptions, t),
            _buildDropdown(r, _cpCtrl, 'Chest Pain Type *', _cpOptions, t),
            _buildTextField(r, _bpCtrl, 'Resting BP (50–250 mm Hg) *', Icons.monitor_heart_outlined, t, keyboardType: TextInputType.number),
            _buildTextField(r, _cholCtrl, 'Cholesterol (100–600 mg/dl)*', Icons.medical_services_outlined, t, keyboardType: TextInputType.number),
            _buildDropdown(r, _fbsCtrl, 'Fasting Blood Sugar *', _fbsOptions, t),
            _buildDropdown(r, _restEcgCtrl, 'Resting ECG *', _restEcgOptions, t),
            _buildTextField(r, _heartRateCtrl, 'Max Heart Rate (60–250 bpm)*', Icons.favorite_outlined, t, keyboardType: TextInputType.number),
            _buildDropdown(r, _exangCtrl, 'Exercise Angina *', _exangOptions, t),
            _buildTextField(r, _oldpeakCtrl, 'ST Depression (0–10 mm) *', Icons.trending_down_outlined, t, keyboardType: TextInputType.number),
            _buildDropdown(r, _slopeCtrl, 'ST Slope *', _slopeOptions, t),

            if (_error != null) ...[
              SizedBox(height: r.sp(14)),
              Container(
                padding: EdgeInsets.all(r.sp(12)),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(r.cardRadius),
                ),
                child: Text(_error!,
                    style: TextStyle(
                        color: Colors.red, fontSize: r.fs(13))),
              ),
            ],

            SizedBox(height: r.sp(22)),

            SizedBox(
              width: double.infinity,
              height: r.btnH,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitPrediction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sageGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.cardRadius)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('Generate Prediction',
                        style: TextStyle(
                            fontSize: r.fs(15), fontWeight: FontWeight.w600)),
              ),
            ),

            SizedBox(height: r.sp(14)),

            Text(
              'Clinical decision support only. Final diagnosis remains the responsibility of the physician.',
              style: TextStyle(
                  color: t.textMuted,
                  fontSize: r.fs(12)),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: r.sp(20)),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

  // Fixed _buildTextField - t as positional parameter
  Widget _buildTextField(
    Responsive r,
    TextEditingController c,
    String hint,
    IconData icon,
    AppThemeTokens t, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: r.sp(14)),
      child: TextField(
        controller: c,
        keyboardType: keyboardType,
        style: TextStyle(color: t.textPrimary, fontSize: r.fs(14)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              color: t.textMuted,
              fontSize: r.fs(12)),
          prefixIcon: Icon(icon, color: AppColors.sageGreen),
          filled: true,
          fillColor: t.surface,
          contentPadding: EdgeInsets.symmetric(
              horizontal: r.wp(16), vertical: r.inputVPad),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(r.cardRadius),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(r.cardRadius),
              borderSide: BorderSide(color: t.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(r.cardRadius),
              borderSide: const BorderSide(color: AppColors.sageGreen)),
        ),
      ),
    );
  }

  // Fixed _buildDateOfBirthField
  Widget _buildDateOfBirthField(Responsive r, AppThemeTokens t) {
    return Padding(
      padding: EdgeInsets.only(bottom: r.sp(14)),
      child: GestureDetector(
        onTap: _selectDateOfBirth,
        child: AbsorbPointer(
          child: TextField(
            controller: _dobCtrl,
            style: TextStyle(color: t.textPrimary, fontSize: r.fs(14)),
            decoration: InputDecoration(
              hintText: 'Date of Birth (for patient record)',
              hintStyle: TextStyle(
                  color: t.textMuted,
                  fontSize: r.fs(12)),
              prefixIcon: Icon(Icons.calendar_today, color: AppColors.sageGreen),
              suffixIcon: Icon(Icons.arrow_drop_down, color: AppColors.sageGreen),
              filled: true,
              fillColor: t.surface,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: r.wp(16), vertical: r.inputVPad),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.cardRadius),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.cardRadius),
                  borderSide: BorderSide(color: t.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.cardRadius),
                  borderSide: const BorderSide(color: AppColors.sageGreen)),
            ),
          ),
        ),
      ),
    );
  }

  // Fixed _buildDropdown
  Widget _buildDropdown(
    Responsive r,
    TextEditingController c,
    String hint,
    List<String> items,
    AppThemeTokens t,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: r.sp(14)),
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(r.cardRadius),
          border: Border.all(color: t.border),
          boxShadow: [
            BoxShadow(
              color: t.textPrimary.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: DropdownButtonFormField<String>(
          value: c.text.isEmpty ? null : c.text,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: t.textMuted,
                fontSize: r.fs(12)),
            prefixIcon: Icon(Icons.arrow_drop_down_circle_outlined, color: AppColors.sageGreen),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
                horizontal: r.wp(16), vertical: r.sp(12)),
          ),
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item, style: TextStyle(fontSize: r.fs(13), color: t.textPrimary)),
          )).toList(),
          onChanged: (value) => c.text = value ?? '',
          style: TextStyle(color: t.textPrimary, fontSize: r.fs(13)),
        ),
      ),
    );
  }

  // Fixed _buildPatientDropdown
  Widget _buildPatientDropdown(Responsive r, AppThemeTokens t) {
    return Padding(
      padding: EdgeInsets.only(bottom: r.sp(14)),
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(r.cardRadius),
          border: Border.all(color: t.border),
          boxShadow: [
            BoxShadow(
              color: t.textPrimary.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: DropdownButtonFormField<int>(
          value: _selectedPatientId,
          isExpanded: true,
          decoration: InputDecoration(
            hintText: 'Select Patient (Optional)',
            hintStyle: TextStyle(color: t.textMuted, fontSize: r.fs(13)),
            prefixIcon: Icon(Icons.person_outline, color: AppColors.sageGreen),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
                horizontal: r.wp(16), vertical: r.sp(12)),
          ),
          items: [
            const DropdownMenuItem<int>(
                value: null,
                child: Text('None (New Patient)')),
            ..._patients.map((p) => DropdownMenuItem<int>(
                value: p['id'],
                child: Text('${p['first_name']} ${p['last_name']}',
                    style: TextStyle(color: t.textPrimary)))),
          ],
          onChanged: _onPatientSelected,
          style: TextStyle(color: t.textPrimary, fontSize: r.fs(13)),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════
//  PREDICTION RESULT SCREEN (with Dark Mode)
// ═══════════════════════════════════════
class PredictionResultScreen extends StatelessWidget {
  final int    predictionId;
  final double riskScore;
  final String riskCategory;
  final bool   hasDisease;
  final String? patientName;
  final int    patientAge;
  final String? patientGender;
  final Map<String, dynamic>? predictionData;

  const PredictionResultScreen({
    super.key,
    required this.predictionId,
    required this.riskScore,
    required this.riskCategory,
    required this.hasDisease,
    this.patientName,
    required this.patientAge,
    this.patientGender,
    this.predictionData,
  });

  Future<void> _exportPDF() async {
    final p = predictionData ?? {
      'id': predictionId, 'patient_name': patientName,
      'age': patientAge, 'sex': patientGender == 'Male' ? 1 : 0,
      'risk_score': riskScore, 'risk_category': riskCategory,
      'created_at': DateTime.now().toIso8601String(),
    };
    await PdfService.exportPrediction(p);
  }

  void _discussWithChatbot(BuildContext context) {
    final patientData = {
      'patient_name': patientName ?? 'Patient',
      'age':          patientAge,
      'gender':       patientGender ?? 'Not specified',
      'chest_pain_type': predictionData?['cp'] != null
          ? _getCpType(predictionData!['cp']) : 'Not specified',
      'resting_bp':        predictionData?['trestbps'] ?? 0,
      'cholesterol':       predictionData?['chol'] ?? 0,
      'fasting_blood_sugar': predictionData?['fbs'] == 1 ? '>120 mg/dl' : '≤120 mg/dl',
      'resting_ecg': predictionData?['restecg'] != null
          ? _getRestEcg(predictionData!['restecg']) : 'Not specified',
      'max_heart_rate': predictionData?['thalach'] ?? 0,
      'exercise_angina': predictionData?['exang'] == 1 ? 'Yes' : 'No',
      'st_depression':   predictionData?['oldpeak'] ?? 0.0,
      'st_slope': predictionData?['slope'] != null
          ? _getSlope(predictionData!['slope']) : 'Not specified',
      'risk_score':    riskScore,
      'risk_category': riskCategory,
      'has_disease':   hasDisease,
    };
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatbotScreen(initialContext: patientData)));
  }

  String _getCpType(int cp) => ['Typical Angina', 'Atypical Angina', 'Non-anginal Pain', 'Asymptomatic'].elementAtOrNull(cp) ?? 'Not specified';
  String _getRestEcg(int v)  => ['Normal', 'ST-T Abnormality', 'LV Hypertrophy'].elementAtOrNull(v) ?? 'Not specified';
  String _getSlope(int v)    => ['Upsloping', 'Flat', 'Downsloping'].elementAtOrNull(v) ?? 'Not specified';

  @override
  Widget build(BuildContext context) {
    final r              = Responsive.of(context);
    final t              = AppThemeTokens.of(context);
    final riskPercentage = (riskScore * 100).toInt();
    final riskColor      = riskCategory == 'high'
        ? const Color(0xFFC97C5D)
        : riskCategory == 'moderate'
            ? const Color(0xFFB89B5E)
            : AppColors.sageGreen;
    final recommendation = riskCategory == 'high'
        ? 'Immediate cardiology consultation recommended. Further diagnostic tests may be necessary.'
        : riskCategory == 'moderate'
            ? 'Monitor closely. Consider lifestyle modifications and regular check-ups.'
            : 'Low risk profile. Continue healthy lifestyle and routine screenings.';

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text('Prediction Result',
            style: TextStyle(fontSize: r.fs(18), fontWeight: FontWeight.w700, color: t.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation:       0,
        foregroundColor: t.textPrimary,
        actions: [
          IconButton(
              icon:    const Icon(Icons.picture_as_pdf),
              onPressed: _exportPDF,
              tooltip: 'Export PDF'),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(r.hp),
        child: Column(
          children: [
            // Risk circle
            Container(
              width:  r.wp(165),
              height: r.wp(165),
              decoration: BoxDecoration(
                shape:  BoxShape.circle,
                color:  riskColor.withOpacity(0.08),
                border: Border.all(color: riskColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: riskColor.withOpacity(0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$riskPercentage%',
                      style: TextStyle(
                        fontSize:   r.fs(44),
                        fontWeight: FontWeight.bold,
                        color:      riskColor,
                      ),
                    ),
                    SizedBox(height: r.sp(6)),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.wp(14), vertical: r.sp(5)),
                      decoration: BoxDecoration(
                        color:        riskColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        riskCategory.toUpperCase(),
                        style: TextStyle(
                            color:      Colors.white,
                            fontSize:   r.fs(12),
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: r.sp(22)),

            // Patient info card
            _InfoCard(
              title: 'Patient Information',
              r: r,
              t: t,
              children: [
                if (patientName != null && patientName!.isNotEmpty)
                  _row('Name', patientName!, r, t),
                _row('Age', '$patientAge years', r, t),
                if (patientGender != null)
                  _row('Gender', patientGender!, r, t),
                _row('Prediction ID', '#$predictionId', r, t),
              ],
            ),

            SizedBox(height: r.sp(14)),

            // Recommendation card
            _InfoCard(
              title: 'Clinical Recommendation',
              r: r,
              t: t,
              children: [
                Text(recommendation,
                    style: TextStyle(
                        fontSize: r.fs(14),
                        height:   1.55,
                        color:    t.textPrimary.withOpacity(0.8))),
              ],
            ),

            SizedBox(height: r.sp(22)),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.sageGreen,
                      side: const BorderSide(color: AppColors.sageGreen),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.cardRadius)),
                      padding: EdgeInsets.symmetric(vertical: r.sp(13)),
                    ),
                    child: Text('New Prediction',
                        style: TextStyle(fontSize: r.fs(14), color: AppColors.sageGreen)),
                  ),
                ),
                SizedBox(width: r.wp(10)),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _discussWithChatbot(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sageGreen,
                      foregroundColor: Colors.white,
                      elevation:       0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.cardRadius)),
                      padding: EdgeInsets.symmetric(vertical: r.sp(13)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: r.wp(16), color: Colors.white),
                        SizedBox(width: r.wp(6)),
                        Text('Discuss', style: TextStyle(fontSize: r.fs(13), color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: r.sp(10)),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context, '/home', (route) => false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: t.textPrimary,
                  side: BorderSide(color: t.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.cardRadius)),
                  padding: EdgeInsets.symmetric(vertical: r.sp(13)),
                ),
                child: Text('Back to Home',
                    style: TextStyle(fontSize: r.fs(14), color: t.textPrimary)),
              ),
            ),

            SizedBox(height: r.sp(20)),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, Responsive r, AppThemeTokens t) => Padding(
        padding: EdgeInsets.only(top: r.sp(6)),
        child: Row(
          children: [
            SizedBox(
              width: r.wp(80),
              child: Text(label,
                  style: TextStyle(
                      color:    t.textMuted,
                      fontSize: r.fs(13))),
            ),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      color:      t.textPrimary,
                      fontSize:   r.fs(13),
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
}

class _InfoCard extends StatelessWidget {
  final String         title;
  final List<Widget>   children;
  final Responsive     r;
  final AppThemeTokens t;

  const _InfoCard({
    required this.title,
    required this.children,
    required this.r,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: EdgeInsets.all(r.sp(16)),
      decoration: BoxDecoration(
        color:        t.surface,
        borderRadius: BorderRadius.circular(r.cardRadius),
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
          Text(title,
              style: TextStyle(
                  fontSize:   r.fs(15),
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary)),
          SizedBox(height: r.sp(10)),
          ...children,
        ],
      ),
    );
  }
}