// lib/services/medical_validator.dart
class MedicalValidator {
  static const List<String> _criticalTerms = [
    'diagnosis', 'diagnostic', 'prescribe', 'treatment',
    'medication', 'drug', 'dose', 'dosage', 'surgery'
  ];

  String validateAndSanitize(String response) {
    String sanitized = response;
    

    // Check critical terms
    for (var term in _criticalTerms) {
      if (sanitized.toLowerCase().contains(term)) {
        sanitized = _addWarningForTerm(sanitized, term);
      }
    }

    return sanitized;
  }

  String _addWarningForTerm(String response, String term) {
        final warning = '\n\n⚠️ Note: The use of "$term" should be confirmed by a healthcare professional.';
        return response + warning;
  }
}