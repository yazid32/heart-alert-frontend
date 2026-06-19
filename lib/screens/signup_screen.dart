// lib/screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../services/file_upload_service.dart';
import '../models/user.dart';
import '../utils/email_validator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../widgets/email_verification_dialog.dart';
import 'waiting_approval_screen.dart';
import 'package:universal_io/io.dart';
import '../services/web_upload_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, this.inviteToken});
  final String? inviteToken;
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _step = 0;
  String? _inviteToken;
  // Step 1
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _keepSaved = false;
  bool _isLoading = false;
  Timer? _debounceTimer;
  
  // Step 1 Errors
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  // Step 2
  final _licenseCtrl = TextEditingController();
  final _hospitalCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _country;
  String? _specialty;
  String? _selectedCountryCode = '+213';

  // Step 2 Errors
  String? _licenseError;
  String? _hospitalError;
  String? _phoneError;
  String? _countryError;
  String? _specialtyError;
  
  // Phone verification status
  bool _isVerifyingPhone = false;
  bool _phoneVerified = false;
  String? _phoneCarrier;

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

  static const _specialties = [
    'Cardiologist',
    'General Practitioner',
    'Internist',
    'Emergency Physician',
    'Nurse',
    'Radiologist',
    'Other'
  ];

// Country codes for phone with flags
final List<Map<String, String>> _countryCodes = [
  {'code': '+213', 'country': 'Algeria', 'flag': '🇩🇿'},
  {'code': '+33', 'country': 'France', 'flag': '🇫🇷'},
  {'code': '+1', 'country': 'USA/Canada', 'flag': '🇺🇸'},
  {'code': '+44', 'country': 'UK', 'flag': '🇬🇧'},
  {'code': '+49', 'country': 'Germany', 'flag': '🇩🇪'},
  {'code': '+212', 'country': 'Morocco', 'flag': '🇲🇦'},
  {'code': '+216', 'country': 'Tunisia', 'flag': '🇹🇳'},
  {'code': '+20', 'country': 'Egypt', 'flag': '🇪🇬'},
  {'code': '+966', 'country': 'Saudi Arabia', 'flag': '🇸🇦'},
  {'code': '+971', 'country': 'UAE', 'flag': '🇦🇪'},
  {'code': '+961', 'country': 'Lebanon', 'flag': '🇱🇧'},
  {'code': '+962', 'country': 'Jordan', 'flag': '🇯🇴'},
];

  // Step 3 - Documents
  String? _medLicenseFile;
  String? _govIdFile;
  String? _medLicensePath;
  String? _govIdPath;
  String? _medLicensePreview;
  String? _govIdPreview;
  bool _isUploadingMedLicense = false;
  bool _isUploadingGovId = false;

  // Step 4
  bool _acceptedTerms = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  static const _subtitles = [
    "Let's get you started",
    'Professional information',
    'Documents',
    'Terms & Privacy',
  ];

@override
void initState() {
  super.initState();

  // Check for invite token from constructor parameter (mobile deep link)
  if (widget.inviteToken != null && widget.inviteToken!.isNotEmpty) {
    _inviteToken = widget.inviteToken;
    print('📧 Invite token from constructor: $_inviteToken');
  }
  
  // Check for invite token from URL (web - handles both query and hash)
  else {
    if (kIsWeb) {
      // Try to get token from query parameters
      final uri = Uri.base;
      String? token = uri.queryParameters['invite_token'];
      
      // If not found in query, try to get it from the hash fragment
      if (token == null || token.isEmpty) {
        final hash = uri.fragment;
        if (hash.contains('invite_token=')) {
          final startIndex = hash.indexOf('invite_token=') + 13;
          final endIndex = hash.indexOf('&', startIndex);
          if (endIndex != -1) {
            token = hash.substring(startIndex, endIndex);
          } else {
            token = hash.substring(startIndex);
          }
          // Also handle URL encoding
          token = Uri.decodeComponent(token);
        }
      }
      
      if (token != null && token.isNotEmpty) {
        _inviteToken = token;
        print('📧 Invite token from web URL: $_inviteToken');
      }
    }
  }
  
  _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  _slideAnim = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
  _fadeCtrl.forward();
  
  // Setup real-time email check
  _emailCtrl.addListener(_onEmailChanged);
  
  // Add listener for phone verification
  _phoneCtrl.addListener(_onPhoneChanged);
}


  @override
  void dispose() {
    _pageCtrl.dispose();
    _debounceTimer?.cancel();
    _phoneDebounceTimer?.cancel();
    _emailCtrl.removeListener(_onEmailChanged);
    _phoneCtrl.removeListener(_onPhoneChanged);
    for (final c in [
      _nameCtrl,
      _emailCtrl,
      _passCtrl,
      _confirmCtrl,
      _licenseCtrl,
      _hospitalCtrl,
      _phoneCtrl,
    ]) {
      c.dispose();
    }
    _fadeCtrl.dispose();
    super.dispose();
  }

  // Real-time email validation with debounce
  void _onEmailChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final email = _emailCtrl.text.trim();
      if (email.isNotEmpty) {
        // Use the enhanced EmailValidator
        final validationError = EmailValidator.validate(email);
        
        if (validationError != null) {
          setState(() {
            _emailError = validationError;
          });
          return;
        }
        
        // Check if email exists on server
        try {
          final exists = await ApiService.checkEmailExists(email);
          if (mounted) {
            setState(() {
              _emailError = exists ? 'Email already registered' : null;
            });
          }
        } catch (e) {
          // Ignore network errors during typing
        }
      } else {
        setState(() {
          _emailError = null;
        });
      }
    });
  }
  
  // Phone number changed - verify in real-time
  Timer? _phoneDebounceTimer;
  
  void _onPhoneChanged() {
    if (_phoneDebounceTimer?.isActive ?? false) _phoneDebounceTimer!.cancel();
    _phoneDebounceTimer = Timer(const Duration(milliseconds: 800), () async {
      await _verifyPhoneNumber();
    });
  }
  
  Future<void> _verifyPhoneNumber() async {
    final phoneNumber = _phoneCtrl.text.trim();
    if (phoneNumber.isEmpty) {
      setState(() {
        _phoneVerified = false;
        _phoneCarrier = null;
        _phoneError = null;
      });
      return;
    }
    
    // First do format validation
    final formatError = _validatePhone(phoneNumber);
    if (formatError != null) {
      setState(() {
        _phoneError = formatError;
        _phoneVerified = false;
        _phoneCarrier = null;
      });
      return;
    }
    
    // Then verify with API
    setState(() {
      _isVerifyingPhone = true;
      _phoneError = null;
    });
    
    try {
      final fullNumber = '$_selectedCountryCode${phoneNumber.replaceAll(RegExp(r'\s+'), '')}';
      final result = await ApiService.verifyPhone(fullNumber);
      
      if (mounted) {
        if (result['valid'] == true || result['valid'] == null) {
          final lineType = result['line_type'] ?? '';
          final carrier = result['carrier'] ?? '';
          
          if (lineType.isNotEmpty && lineType != 'mobile') {
            setState(() {
              _phoneError = 'Please enter a mobile number (landline/VoIP not supported)';
              _phoneVerified = false;
              _phoneCarrier = null;
              _isVerifyingPhone = false;
            });
          } else {
            setState(() {
              _phoneError = null;
              _phoneVerified = true;
              _phoneCarrier = carrier;
              _isVerifyingPhone = false;
            });
          }
        } else {
          setState(() {
            _phoneError = result['message'] ?? 'Invalid phone number';
            _phoneVerified = false;
            _phoneCarrier = null;
            _isVerifyingPhone = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _phoneError = null;
          _phoneVerified = true;
          _isVerifyingPhone = false;
        });
      }
    }
  }

  // Enhanced email validation using the validator class
  String? _validateEmail(String email) {
    return EmailValidator.validate(email);
  }

  String? _validatePassword(String password) {
    if (password.isEmpty) return 'Password is required';
    if (password.length < 8) return 'Password must be at least 8 characters';
    if (!password.contains(RegExp(r'[A-Z]'))) return 'Include at least 1 uppercase letter';
    if (!password.contains(RegExp(r'[0-9]'))) return 'Include at least 1 number';
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return 'Include at least 1 special character';
    return null;
  }

  // Enhanced phone validation with international support
  String? _validatePhone(String phone) {
    if (phone.isEmpty) return null;
    
    // Remove all non-digit characters
    String cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    
    // Check if it has country code
    if (cleaned.startsWith('+')) {
      if (cleaned.length < 10 || cleaned.length > 16) {
        return 'Invalid phone number with country code';
      }
    } else {
      // Local number without country code
      if (cleaned.length < 8 || cleaned.length > 12) {
        return 'Enter a valid phone number (8-12 digits)';
      }
    }
    
    return null;
  }

  // Auto-format phone number as user types
  String _formatPhoneNumber(String text) {
    String digits = text.replaceAll(RegExp(r'\D'), '');
    
    if (digits.isEmpty) return '';
    
    // For international format starting with +
    if (text.startsWith('+')) {
      if (digits.length <= 3) return '+$digits';
      if (digits.length <= 6) return '+${digits.substring(0, 3)} ${digits.substring(3)}';
      if (digits.length <= 10) return '+${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
      return '+${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6, 10)} ${digits.substring(10)}';
    }
    
    // Local format
    if (digits.length <= 4) return digits;
    if (digits.length <= 7) return '${digits.substring(0, 4)} ${digits.substring(4)}';
    return '${digits.substring(0, 4)} ${digits.substring(4, 7)} ${digits.substring(7)}';
  }

  String? _validateLicense(String license) {
    if (license.isEmpty) return 'License number is required';
    if (license.length < 5) return 'Enter a valid license number';
    return null;
  }

  String? _validateHospital(String hospital) {
    if (hospital.isEmpty) return 'Hospital name is required';
    return null;
  }

  void _goToStep(int s) {
    setState(() => _step = s);
    _pageCtrl.animateToPage(
      s,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _back() {
    if (_step > 0) _goToStep(_step - 1);
  }

  void _next() async {
    if (_step == 0) {
      // Validate Step 1 fields with enhanced email validation
      setState(() {
        _nameError = _nameCtrl.text.trim().isEmpty ? 'Full name is required' : null;
        _emailError = _validateEmail(_emailCtrl.text.trim());
        _passwordError = _validatePassword(_passCtrl.text);
        _confirmPasswordError = _passCtrl.text != _confirmCtrl.text 
            ? 'Passwords do not match' 
            : null;
      });
      
      if (_nameError == null && _emailError == null && 
          _passwordError == null && _confirmPasswordError == null) {
        
        setState(() => _isLoading = true);
        
        try {
          final bool emailExists = await ApiService.checkEmailExists(
            _emailCtrl.text.trim()
          );
          
          if (emailExists) {
            setState(() {
              _emailError = 'Email already registered. Please use another email or login.';
              _isLoading = false;
            });
          } else {
            setState(() => _isLoading = false);
            _goToStep(1);
          }
        } catch (e) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error checking email. Please try again.')),
          );
        }
      }
    }
    else if (_step == 1) {
      // Validate Step 2
      setState(() {
        _licenseError = _validateLicense(_licenseCtrl.text.trim());
        _hospitalError = _validateHospital(_hospitalCtrl.text.trim());
        _countryError = _country == null ? 'Please select a country' : null;
        _specialtyError = _specialty == null ? 'Please select a specialty' : null;
      });
      
      // Check phone verification
      final phoneNumber = _phoneCtrl.text.trim();
      if (phoneNumber.isNotEmpty && !_phoneVerified && !_isVerifyingPhone) {
        await _verifyPhoneNumber();
        if (mounted && !_phoneVerified) {
          setState(() {
            _phoneError ??= 'Please enter a valid mobile number';
          });
        }
      }
      
      if (_licenseError == null && _hospitalError == null && 
          _countryError == null && _specialtyError == null &&
          (phoneNumber.isEmpty || _phoneVerified)) {
        _goToStep(2);
      }
    }
    else if (_step == 2) {
      _goToStep(3);
    }
    else {
      await _submitSignup();
    }
  }

Future<void> _submitSignup() async {
  if (!_acceptedTerms) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please accept the Terms and Privacy Policy')),
    );
    return;
  }

  // Show loading dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final nameParts = _nameCtrl.text.trim().split(' ');
    final firstName = nameParts.first;
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    
    String fullPhone = '';
    if (_phoneCtrl.text.trim().isNotEmpty) {
      fullPhone = '$_selectedCountryCode${_phoneCtrl.text.trim().replaceAll(RegExp(r'\s+'), '')}';
    }
    
    final normalizedEmail = EmailValidator.normalize(_emailCtrl.text.trim());

    final response = await ApiService.signup(
      email: normalizedEmail,
      password: _passCtrl.text,
      firstName: firstName,
      lastName: lastName,
      licenseNumber: _licenseCtrl.text,
      hospital: _hospitalCtrl.text,
      country: _country ?? '',
      specialty: _specialty ?? '',
      phone: fullPhone,
      medicalLicensePath: _medLicensePath,
      governmentIdPath: _govIdPath,
      termsAccepted: _acceptedTerms,
      role: 'doctor',
      inviteToken: _inviteToken,  // ← ADD THIS
    );
    
    final token = response['access_token'];
    await TokenService.saveToken(token);
    
    final user = User.fromJson(response);
    await TokenService.saveUser(user);
    
    if (mounted) Navigator.pop(context);
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WaitingApprovalScreen(
            email: normalizedEmail,
          ),
        ),
      );
    }
    
  } catch (e) {
    if (mounted) Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Signup failed: $e')),
    );
  }
}

Future<void> _pickMedLicense() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['png', 'jpg', 'jpeg', 'pdf'],
  );
  
  if (result != null) {
    final fileName = result.files.single.name;
    
    if (kIsWeb) {
      final bytes = result.files.single.bytes;
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to read file')),
        );
        return;
      }
      
      setState(() {
        _isUploadingMedLicense = true;
        _medLicenseFile = fileName;
      });
      
      try {
        final filePath = await WebUploadService.uploadDocument(
          fileName: fileName,
          bytes: bytes,
          token: null, 
        );
        setState(() {
          _medLicensePath = filePath;
          _medLicensePreview = filePath; // Web Preview update
          _isUploadingMedLicense = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medical license uploaded successfully')),
        );
      } catch (e) {
        setState(() {
          _isUploadingMedLicense = false;
          _medLicenseFile = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } else {
      // MOBILE: Existing code
      File file = File(result.files.single.path!);
      
      String? preview;
      if (fileName.toLowerCase().endsWith('.png') || 
          fileName.toLowerCase().endsWith('.jpg') || 
          fileName.toLowerCase().endsWith('.jpeg')) {
        preview = file.path;
      }
      
      setState(() {
        _isUploadingMedLicense = true;
        _medLicensePreview = preview;
        _medLicenseFile = fileName;
      });
      
      try {
        String filePath = await FileUploadService.uploadDocument(file);
        setState(() {
          _medLicensePath = filePath;
          _isUploadingMedLicense = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medical license uploaded successfully')),
        );
      } catch (e) {
        setState(() {
          _isUploadingMedLicense = false;
          _medLicensePreview = null;
          _medLicenseFile = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }
}

Future<void> _pickGovId() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['png', 'jpg', 'jpeg', 'pdf'],
  );
  
  if (result != null) {
    final fileName = result.files.single.name;
    
    if (kIsWeb) {
      final bytes = result.files.single.bytes;
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to read file')),
        );
        return;
      }
      
      setState(() {
        _isUploadingGovId = true;
        _govIdFile = fileName;
      });
      
      try {
        final filePath = await WebUploadService.uploadDocument(
          fileName: fileName,
          bytes: bytes,
          token: null, 
        );
        setState(() {
          _govIdPath = filePath;
          _govIdPreview = filePath; // Web Preview update
          _isUploadingGovId = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Government ID uploaded successfully')),
        );
      } catch (e) {
        setState(() {
          _isUploadingGovId = false;
          _govIdFile = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } else {
      // MOBILE: Existing code
      File file = File(result.files.single.path!);
      
      String? preview;
      if (fileName.toLowerCase().endsWith('.png') || 
          fileName.toLowerCase().endsWith('.jpg') || 
          fileName.toLowerCase().endsWith('.jpeg')) {
        preview = file.path;
      }
      
      setState(() {
        _isUploadingGovId = true;
        _govIdPreview = preview;
        _govIdFile = fileName;
      });
      
      try {
        String filePath = await FileUploadService.uploadDocument(file);
        setState(() {
          _govIdPath = filePath;
          _isUploadingGovId = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Government ID uploaded successfully')),
        );
      } catch (e) {
        setState(() {
          _isUploadingGovId = false;
          _govIdPreview = null;
          _govIdFile = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }
}

  void _goLogin() => Navigator.pushReplacementNamed(context, '/login');

  static const double _wideBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= _wideBreakpoint;

    final formColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fixed header (same as before)
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isWide)
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.sageGreen,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.sageGreen.withOpacity(0.30),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/logo.png',
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.emergency,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'HEART ALERT',
                            style: TextStyle(
                              color: AppColors.black,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.5,
                            ),
                          ),
                        ],
                      ),
                      if (!isWide) const SizedBox(height: 28),
                      Text(
                        isWide ? 'Create your account' : 'Welcome.',
                        style: const TextStyle(
                          color: AppColors.black,
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Align(
                          key: ValueKey(_step),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _subtitles[_step],
                            style: TextStyle(
                              color: AppColors.black.withOpacity(0.4),
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: List.generate(
                          4,
                          (i) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: i < 3 ? 6 : 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 350),
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: i <= _step
                                          ? AppColors.sageGreen
                                          : AppColors.black.withOpacity(0.09),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Step ${_step + 1} of 4',
                        style: TextStyle(
                          color: AppColors.black.withOpacity(0.35),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageCtrl,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _Step1(
                        nameCtrl: _nameCtrl,
                        emailCtrl: _emailCtrl,
                        passCtrl: _passCtrl,
                        confirmCtrl: _confirmCtrl,
                        obscurePass: _obscurePass,
                        obscureConfirm: _obscureConfirm,
                        keepSaved: _keepSaved,
                        nameError: _nameError,
                        emailError: _emailError,
                        passwordError: _passwordError,
                        confirmPasswordError: _confirmPasswordError,
                        isLoading: _isLoading,
                        onTogglePass: () => setState(() => _obscurePass = !_obscurePass),
                        onToggleConfirm: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        onToggleKeep: () => setState(() => _keepSaved = !_keepSaved),
                        onNext: _next,
                        onLogin: _goLogin,
                      ),
                      _Step2(
                        licenseCtrl: _licenseCtrl,
                        hospitalCtrl: _hospitalCtrl,
                        phoneCtrl: _phoneCtrl,
                        country: _country,
                        specialty: _specialty,
                        countryCodes: _countryCodes,
                        selectedCountryCode: _selectedCountryCode,
                        countries: _countries,
                        specialties: _specialties,
                        licenseError: _licenseError,
                        hospitalError: _hospitalError,
                        phoneError: _phoneError,
                        countryError: _countryError,
                        specialtyError: _specialtyError,
                        isVerifyingPhone: _isVerifyingPhone,
                        phoneVerified: _phoneVerified,
                        phoneCarrier: _phoneCarrier,
                        onCountryChanged: (v) => setState(() => _country = v),
                        onSpecialtyChanged: (v) => setState(() => _specialty = v),
                        onCountryCodeChanged: (code) {
                          setState(() => _selectedCountryCode = code);
                          if (_phoneCtrl.text.trim().isNotEmpty) {
                            _verifyPhoneNumber();
                          }
                        },
                        onPhoneChanged: (value) {
                          String formatted = _formatPhoneNumber(value);
                          if (formatted != value) {
                            _phoneCtrl.value = TextEditingValue(
                              text: formatted,
                              selection: TextSelection.collapsed(offset: formatted.length),
                            );
                          }
                        },
                        onBack: _back,
                        onNext: _next,
                        onLogin: _goLogin,
                      ),
                      _Step3(
                        medLicenseFile: _medLicenseFile,
                        medLicensePreview: _medLicensePreview,
                        govIdFile: _govIdFile,
                        govIdPreview: _govIdPreview,
                        isUploadingMedLicense: _isUploadingMedLicense,
                        isUploadingGovId: _isUploadingGovId,
                        onPickMedLicense: _pickMedLicense,
                        onPickGovId: _pickGovId,
                        onBack: _back,
                        onNext: _next,
                        onLogin: _goLogin,
                      ),
                      _Step4(
                        accepted: _acceptedTerms,
                        onToggle: () => setState(() => _acceptedTerms = !_acceptedTerms),
                        onBack: _back,
                        onSubmit: _next,
                        onLogin: _goLogin,
                      ),
                    ],
                  ),
                ),
              ],
            );

    return Scaffold(
      backgroundColor: isWide ? Colors.white : AppColors.cream,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: isWide
                ? Row(
                    children: [
                      const Expanded(flex: 5, child: _SignupBrandPanel()),
                      Expanded(
                        flex: 7,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 620),
                            child: formColumn,
                          ),
                        ),
                      ),
                    ],
                  )
                : formColumn,
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Wide-layout brand panel ─────────────────────────
// Decorative panel shown on web/desktop widths, to the side of the signup
// form. Purely visual — no state, no navigation, no logic.
class _SignupBrandPanel extends StatelessWidget {
  const _SignupBrandPanel();

  static const _checklist = [
    (Icons.badge_outlined, 'Medical license verification'),
    (Icons.checklist_rounded, 'Quick 4-step setup'),
    (Icons.verified_user_outlined, 'Reviewed by our clinical team'),
  ];

  @override
  Widget build(BuildContext context) {
    final darkGreen = Color.lerp(AppColors.sageGreen, Colors.black, 0.35)!;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.sageGreen, darkGreen],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _SignupPulsePainter()),
          ),
          Positioned(
            bottom: -70,
            left: -70,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(48, 40, 48, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.emergency,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'HEART ALERT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 64),
                  const Text(
                    'Join the clinicians\ncatching risk early.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1.18,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Set up your account in a few steps and start screening '
                    'patients with explainable, real-time cardiac risk predictions.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.82),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  ..._checklist.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(f.$1, color: Colors.white, size: 17),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              f.$2,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.92),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
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
}

// A quiet heartbeat-line motif, drawn once as a background flourish —
// mirrors the one used on the login screen for visual continuity.
class _SignupPulsePainter extends CustomPainter {
  const _SignupPulsePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final baseline = size.height * 0.38;
    final path = Path()..moveTo(0, baseline);
    final segment = size.width / 5;

    path.lineTo(segment * 0.9, baseline);
    path.lineTo(segment * 1.05, baseline - 18);
    path.lineTo(segment * 1.2, baseline + 46);
    path.lineTo(segment * 1.4, baseline - 8);
    path.lineTo(segment * 1.7, baseline);
    path.lineTo(segment * 2.9, baseline);
    path.lineTo(segment * 3.05, baseline - 18);
    path.lineTo(segment * 3.2, baseline + 46);
    path.lineTo(segment * 3.4, baseline - 8);
    path.lineTo(segment * 3.7, baseline);
    path.lineTo(size.width, baseline);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==================== STEP 2 WITH FLAGS ====================
class _Step2 extends StatelessWidget {
  final TextEditingController licenseCtrl, hospitalCtrl, phoneCtrl;
  final String? country, specialty, selectedCountryCode;
  final List<Map<String, String>> countryCodes;
  final List<String> countries, specialties;
  final String? licenseError, hospitalError, phoneError, countryError, specialtyError;
  final bool isVerifyingPhone;
  final bool phoneVerified;
  final String? phoneCarrier;
  final ValueChanged<String?> onCountryChanged, onSpecialtyChanged;
  final ValueChanged<String> onCountryCodeChanged;
  final ValueChanged<String> onPhoneChanged;
  final VoidCallback onBack, onNext, onLogin;

  const _Step2({
    required this.licenseCtrl,
    required this.hospitalCtrl,
    required this.phoneCtrl,
    required this.country,
    required this.specialty,
    required this.countryCodes,
    required this.selectedCountryCode,
    required this.countries,
    required this.specialties,
    this.licenseError,
    this.hospitalError,
    this.phoneError,
    this.countryError,
    this.specialtyError,
    this.isVerifyingPhone = false,
    this.phoneVerified = false,
    this.phoneCarrier,
    required this.onCountryChanged,
    required this.onSpecialtyChanged,
    required this.onCountryCodeChanged,
    required this.onPhoneChanged,
    required this.onBack,
    required this.onNext,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Label('Medical license number *'),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InputField(
                  controller: licenseCtrl,
                  hint: 'e.g. ML-123456',
                  prefixIcon: Icons.badge_outlined,
                  hasError: licenseError != null,
                ),
                if (licenseError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 12),
                    child: Text(licenseError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const _Label('Country of license *'),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Dropdown(
                  hint: 'Select country',
                  value: country,
                  items: countries,
                  onChanged: onCountryChanged,
                  prefixIcon: Icons.flag_outlined,
                  hasError: countryError != null,
                ),
                if (countryError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 12),
                    child: Text(countryError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const _Label('Specialty *'),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Dropdown(
                  hint: 'Select specialty',
                  value: specialty,
                  items: specialties,
                  onChanged: onSpecialtyChanged,
                  prefixIcon: Icons.medical_services_outlined,
                  hasError: specialtyError != null,
                ),
                if (specialtyError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 12),
                    child: Text(specialtyError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const _Label('Hospital / Clinic name *'),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InputField(
                  controller: hospitalCtrl,
                  hint: 'e.g. Central Hospital',
                  prefixIcon: Icons.local_hospital_outlined,
                  hasError: hospitalError != null,
                ),
                if (hospitalError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 12),
                    child: Text(hospitalError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const _Label('Phone number'),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Phone number row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Country code dropdown
                  SizedBox(
                    width: 110,  
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: phoneError != null ? Colors.red : AppColors.black.withOpacity(0.08),
                          width: phoneError != null ? 1.5 : 1,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCountryCode,
                          isExpanded: true,
                          icon: Icon(Icons.keyboard_arrow_down_rounded, 
                              color: AppColors.black.withOpacity(0.35), size: 18),
                          dropdownColor: AppColors.cream,
                          borderRadius: BorderRadius.circular(14),
                          style: const TextStyle(color: AppColors.black, fontSize: 13),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          items: countryCodes.map((c) {
                            final flag = c['flag'] ?? '';
                            final code = c['code']!;
                            return DropdownMenuItem(
                              value: code,
                              child: Row(
                                children: [
                                  Text(flag, style: const TextStyle(fontSize: 14)),
                                  const SizedBox(width: 4),
                                  Text(code, style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) onCountryCodeChanged(value);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8), 
                  // Phone number input
                  Expanded(
                    child: Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: AppColors.black, fontSize: 14),
                          onChanged: onPhoneChanged,
                          decoration: InputDecoration(
                            hintText: '123456789',
                            hintStyle: TextStyle(color: AppColors.black.withOpacity(0.3), fontSize: 13),
                            filled: true,
                            fillColor: AppColors.black.withOpacity(0.04),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: phoneError != null ? Colors.red : AppColors.black.withOpacity(0.08),
                                width: phoneError != null ? 1.5 : 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: phoneError != null ? Colors.red : AppColors.sageGreen,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        if (phoneCtrl.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: isVerifyingPhone
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : phoneVerified
                                    ? const Icon(Icons.check_circle, color: Colors.green, size: 16)
                                    : const Icon(Icons.error, color: Colors.red, size: 16),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
                  if (phoneCarrier != null && phoneVerified)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 12),
                    child: Text(
                      '✓ Verified: $phoneCarrier',
                      style: const TextStyle(color: Colors.green, fontSize: 11),
                    ),
                  ),
                if (phoneError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 12),
                    child: Text(phoneError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 12),
                  child: Text(
                    'Enter your mobile number for account recovery',
                    style: TextStyle(color: AppColors.black.withOpacity(0.4), fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            _StepActions(
              backLabel: 'Back',
              nextLabel: 'Next',
              onBack: onBack,
              onNext: onNext,
            ),
            const SizedBox(height: 28),
            _LoginLink(onLogin: onLogin),
            const SizedBox(height: 28),
          ],
        ),
      );
}

// ==================== STEP 1 ====================
class _Step1 extends StatelessWidget {
  final TextEditingController nameCtrl, emailCtrl, passCtrl, confirmCtrl;
  final bool obscurePass, obscureConfirm, keepSaved;
  final String? nameError, emailError, passwordError, confirmPasswordError;
  final bool isLoading;
  final VoidCallback onTogglePass, onToggleConfirm, onToggleKeep, onNext, onLogin;

  const _Step1({
    required this.nameCtrl,
    required this.emailCtrl,
    required this.passCtrl,
    required this.confirmCtrl,
    required this.obscurePass,
    required this.obscureConfirm,
    required this.keepSaved,
    required this.isLoading,
    this.nameError,
    this.emailError,
    this.passwordError,
    this.confirmPasswordError,
    required this.onTogglePass,
    required this.onToggleConfirm,
    required this.onToggleKeep,
    required this.onNext,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Label('Full name *'),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InputField(
                  controller: nameCtrl,
                  hint: 'John Smith',
                  prefixIcon: Icons.person_outline_rounded,
                  hasError: nameError != null,
                ),
                if (nameError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 12),
                    child: Text(nameError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            const _Label('Email *'),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InputField(
                  controller: emailCtrl,
                  hint: 'doctor@hospital.com',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.mail_outline_rounded,
                  hasError: emailError != null,
                ),
                if (emailError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 12),
                    child: Text(emailError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            const _Label('Password *'),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InputField(
                  controller: passCtrl,
                  hint: '••••••••',
                  obscure: obscurePass,
                  prefixIcon: Icons.lock_outline_rounded,
                  suffix: _EyeBtn(obscure: obscurePass, onTap: onTogglePass),
                  hasError: passwordError != null,
                ),
                if (passwordError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 12),
                    child: Text(passwordError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 12),
                    child: Text(
                      'Min 8 chars, 1 uppercase, 1 number, 1 special character',
                      style: TextStyle(color: AppColors.black.withOpacity(0.4), fontSize: 10),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            const _Label('Confirm password *'),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InputField(
                  controller: confirmCtrl,
                  hint: '••••••••',
                  obscure: obscureConfirm,
                  prefixIcon: Icons.lock_outline_rounded,
                  suffix: _EyeBtn(obscure: obscureConfirm, onTap: onToggleConfirm),
                  hasError: confirmPasswordError != null,
                ),
                if (confirmPasswordError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 12),
                    child: Text(confirmPasswordError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            const _Label('Role'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.sageGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.sageGreen, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.medical_services_rounded, color: AppColors.sageGreen, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Doctor',
                    style: TextStyle(
                      color: AppColors.sageGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Note: Assistant accounts can only be created through doctor requests.',
              style: TextStyle(color: Colors.orange, fontSize: 11),
            ),
            const SizedBox(height: 28),
            _PrimaryBtn(label: 'Next', onTap: onNext, isLoading: isLoading),
            const SizedBox(height: 26),
            _LoginLink(onLogin: onLogin),
            const SizedBox(height: 28),
          ],
        ),
      );
}

// ==================== STEP 3 ====================
class _Step3 extends StatelessWidget {
  final String? medLicenseFile, govIdFile;
  final String? medLicensePreview, govIdPreview;
  final bool isUploadingMedLicense, isUploadingGovId;
  final VoidCallback onPickMedLicense, onPickGovId, onBack, onNext, onLogin;

  const _Step3({
    required this.medLicenseFile,
    required this.govIdFile,
    this.medLicensePreview,
    this.govIdPreview,
    this.isUploadingMedLicense = false,
    this.isUploadingGovId = false,
    required this.onPickMedLicense,
    required this.onPickGovId,
    required this.onBack,
    required this.onNext,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Label('Medical License'),
            const SizedBox(height: 10),
            _UploadTile(
              filename: medLicenseFile,
              previewPath: medLicensePreview,
              placeholder: 'Select your Medical License file',
              hint: 'png, jpg, pdf  ·  max 5MB',
              onTap: onPickMedLicense,
              isUploading: isUploadingMedLicense,
              fileExtension: medLicenseFile?.split('.').last,
              isWeb: kIsWeb,
            ),
            const SizedBox(height: 20),
            const _Label('Government ID'),
            const SizedBox(height: 10),
            _UploadTile(
              filename: govIdFile,
              previewPath: govIdPreview,
              placeholder: 'Select your Government ID file',
              hint: 'png, jpg, pdf  ·  max 5MB',
              onTap: onPickGovId,
              isUploading: isUploadingGovId,
              fileExtension: govIdFile?.split('.').last,
              isWeb: kIsWeb,
            ),
            const SizedBox(height: 36),
            _StepActions(
              backLabel: 'Back',
              nextLabel: 'Next',
              onBack: onBack,
              onNext: onNext,
            ),
            const SizedBox(height: 28),
            _LoginLink(onLogin: onLogin),
            const SizedBox(height: 28),
          ],
        ),
      );
}

// ==================== STEP 4 ====================
class _Step4 extends StatelessWidget {
  final bool accepted;
  final VoidCallback onToggle, onBack, onSubmit, onLogin;

  const _Step4({
    required this.accepted,
    required this.onToggle,
    required this.onBack,
    required this.onSubmit,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.black.withOpacity(0.08)),
              ),
              constraints: const BoxConstraints(maxHeight: 300),
              child: const SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TTitle('Terms of Use and Privacy Policy'),
                    SizedBox(height: 8),
                    _TBody(
                      'Heart Alert is an AI-powered clinical decision support tool intended exclusively for licensed healthcare professionals.',
                    ),
                    SizedBox(height: 12),
                    _TTitle('Professional Confirmation'),
                    _TBody('By registering, you confirm that:'),
                    _TBullet('You are a licensed healthcare professional.'),
                    _TBullet(
                      'All credentials and information provided are valid, accurate and complete.',
                    ),
                    _TBullet(
                      'You consent to data processing in accordance with GDPR, HIPAA (where applicable) and relevant laws.',
                    ),
                    _TBullet(
                      'Any false declaration, misuse of professional identity or fraudulent information will result in immediate suspension or permanent termination of access, account deletion, and potential civil or criminal proceedings.',
                    ),
                    SizedBox(height: 12),
                    _TTitle('Medical & AI Disclaimer'),
                    _TBody('Heart Alert is advisory only. It:'),
                    _TBullet('Does not constitute a medical diagnosis.'),
                    _TBullet(
                      'Does not replace independent clinical judgment.',
                    ),
                    _TBullet(
                      'Must be independently verified before any clinical use.',
                    ),
                    _TBody(
                      'You remain solely responsible for all clinical decisions, diagnoses, treatments and patient care.',
                    ),
                    SizedBox(height: 12),
                    _TTitle('Chatbot Use Notice'),
                    _TBody(
                      'Before you continue: Do not enter identifiable patient information unless permitted under applicable data protection laws and institutional policies.',
                    ),
                    SizedBox(height: 12),
                    _TTitle('Emergency Warning'),
                    _TBody(
                      'This application does not replace emergency medical services. Follow established emergency procedures immediately.',
                    ),
                    SizedBox(height: 12),
                    _TTitle('Privacy Notice Summary'),
                    _TBody('Heart Alert collects:'),
                    _TBullet('Professional account information'),
                    _TBullet('Usage and interaction data'),
                    _TBullet(
                      'Clinical input data (non-identifiable unless legally permitted)',
                    ),
                    _TBody(
                      'We do not sell personal data. Deleting your account removes access; certain data may be retained as required by law.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onToggle,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: accepted ? AppColors.sageGreen : Colors.transparent,
                      border: Border.all(
                        color: accepted ? AppColors.sageGreen : AppColors.black.withOpacity(0.25),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: accepted ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'I accept these Terms of Use and Privacy Policy.',
                      style: TextStyle(
                        color: AppColors.black.withOpacity(0.65),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: accepted ? 1.0 : 0.4,
              child: _StepActions(
                backLabel: 'Back',
                nextLabel: 'Create account',
                onBack: onBack,
                onNext: accepted ? onSubmit : () {},
              ),
            ),
            const SizedBox(height: 28),
            _LoginLink(onLogin: onLogin),
            const SizedBox(height: 28),
          ],
        ),
      );
}

// ==================== SHARED WIDGETS ====================
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: AppColors.black.withOpacity(0.6),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      );
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool hasError;

  const _InputField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffix,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.black, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.black.withOpacity(0.3), fontSize: 14),
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: AppColors.black.withOpacity(0.3)) : null,
          suffixIcon: suffix,
          filled: true,
          fillColor: AppColors.black.withOpacity(0.04),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: hasError ? Colors.red : AppColors.black.withOpacity(0.08), width: hasError ? 1.5 : 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: hasError ? Colors.red : AppColors.sageGreen, width: 1.5),
          ),
        ),
      );
}

class _Dropdown extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final IconData? prefixIcon;
  final bool hasError;

  const _Dropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.prefixIcon,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: hasError ? Colors.red : AppColors.black.withOpacity(0.08), width: hasError ? 1.5 : 1),
        ),
        child: DropdownButtonHideUnderline(
          child: ButtonTheme(
            alignedDropdown: true,
            child: DropdownButton<String>(
              value: value,
              hint: Row(
                children: [
                  if (prefixIcon != null) ...[
                    Icon(prefixIcon, size: 18, color: AppColors.black.withOpacity(0.3)),
                    const SizedBox(width: 10),
                  ],
                  Text(hint, style: TextStyle(color: AppColors.black.withOpacity(0.3), fontSize: 14)),
                ],
              ),
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.black.withOpacity(0.35)),
              dropdownColor: AppColors.cream,
              borderRadius: BorderRadius.circular(14),
              style: const TextStyle(color: AppColors.black, fontSize: 15),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      );
}

class _EyeBtn extends StatelessWidget {
  final bool obscure;
  final VoidCallback onTap;

  const _EyeBtn({required this.obscure, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 18,
          color: AppColors.black.withOpacity(0.35),
        ),
      );
}

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  const _PrimaryBtn({
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: isLoading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.sageGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
        ),
      );
}

class _SecondaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SecondaryBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 56,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.sageGreen,
            side: const BorderSide(color: AppColors.sageGreen, width: 1.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
        ),
      );
}

class _StepActions extends StatelessWidget {
  final String backLabel;
  final String nextLabel;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _StepActions({
    required this.backLabel,
    required this.nextLabel,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: _SecondaryBtn(label: backLabel, onTap: onBack)),
          const SizedBox(width: 12),
          Expanded(child: _PrimaryBtn(label: nextLabel, onTap: onNext)),
        ],
      );
}


class _LoginLink extends StatelessWidget {
  final VoidCallback onLogin;
  const _LoginLink({required this.onLogin});

  @override
  Widget build(BuildContext context) => Center(
        child: GestureDetector(
          onTap: onLogin,
          child: RichText(
            text: TextSpan(
              style: TextStyle(color: AppColors.black.withOpacity(0.45), fontSize: 14),
              children: const [
                TextSpan(text: 'Already have an account?  '),
                TextSpan(text: 'Log in', style: TextStyle(color: AppColors.sageGreen, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
}

class _TTitle extends StatelessWidget {
  final String t;
  const _TTitle(this.t);

  @override
  Widget build(BuildContext context) => Text(
        t,
        style: const TextStyle(color: AppColors.black, fontSize: 12, fontWeight: FontWeight.w700, height: 1.5),
      );
}

class _TBody extends StatelessWidget {
  final String t;
  const _TBody(this.t);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(t, style: TextStyle(color: AppColors.black.withOpacity(0.6), fontSize: 12, height: 1.6)),
      );
}

class _TBullet extends StatelessWidget {
  final String t;
  const _TBullet(this.t);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 8, top: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ', style: TextStyle(color: AppColors.sageGreen, fontSize: 12)),
            Expanded(child: Text(t, style: TextStyle(color: AppColors.black.withOpacity(0.6), fontSize: 12, height: 1.6))),
          ],
        ),
      );
}

class _UploadTile extends StatelessWidget {
  final String? filename;
  final String? previewPath;
  final String placeholder, hint;
  final VoidCallback onTap;
  final bool isUploading;
  final String? fileExtension;
  final bool isWeb;

  const _UploadTile({
    required this.filename,
    this.previewPath,
    required this.placeholder,
    required this.hint,
    required this.onTap,
    this.isUploading = false,
    this.fileExtension,
    this.isWeb = false,
  });

  @override
  Widget build(BuildContext context) {
    final uploaded = filename != null;
    final isImage = previewPath != null && !previewPath!.toLowerCase().endsWith('.pdf');
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        decoration: BoxDecoration(
          color: uploaded ? AppColors.sageGreen.withOpacity(0.08) : AppColors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: uploaded ? AppColors.sageGreen.withOpacity(0.5) : AppColors.black.withOpacity(0.12), width: 1.5),
        ),
        child: isUploading
            ? const Column(
                children: [
                  SizedBox(height: 20),
                  Center(child: CircularProgressIndicator()),
                  SizedBox(height: 10),
                  Text('Uploading...'),
                  SizedBox(height: 20),
                ],
              )
            : Column(
                children: [
                if (isImage && previewPath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: (isWeb || previewPath!.startsWith('data:'))
                        ? Image.network(
                            previewPath!,
                            height: 80,
                            width: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.image_not_supported,
                              size: 50,
                              color: AppColors.black.withOpacity(0.3),
                            ),
                          )
                        : Image.file(
                            File(previewPath!),
                            height: 80,
                            width: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.image_not_supported,
                              size: 50,
                              color: AppColors.black.withOpacity(0.3),
                            ),
                          ),
                  )
                  else
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: uploaded 
                            ? AppColors.sageGreen.withOpacity(0.10) 
                            : AppColors.black.withOpacity(0.04),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        uploaded ? Icons.check_circle_outline_rounded : Icons.upload_file_outlined,
                        size: 28,
                        color: uploaded ? AppColors.sageGreen : AppColors.black.withOpacity(0.3),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(uploaded ? filename! : placeholder,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: uploaded ? AppColors.sageGreen : AppColors.black.withOpacity(0.45),
                          fontSize: 13, fontWeight: uploaded ? FontWeight.w600 : FontWeight.w400)),
                  if (!uploaded) ...[
                    const SizedBox(height: 5),
                    Text(hint, textAlign: TextAlign.center, style: TextStyle(color: AppColors.black.withOpacity(0.25), fontSize: 11)),
                  ],
                  if (uploaded && fileExtension != null && !isImage) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.sageGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                      child: Text(fileExtension!.toUpperCase(), style: const TextStyle(color: AppColors.sageGreen, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}