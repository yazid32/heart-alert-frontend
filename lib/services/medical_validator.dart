// lib/services/medical_validator.dart
class MedicalValidator {
  static const List<String> _criticalTerms = [
    'diagnosis', 'diagnostic', 'prescribe', 'treatment',
    'medication', 'drug', 'dose', 'dosage', 'surgery'
  ];

  static const List<String> _disclaimers = [
    'This is not a medical diagnosis.',
    'Please consult a healthcare professional.',
    'This information is for educational purposes.',
    'Clinical judgment should always take precedence.',
    'The information provided is AI-generated and should be verified.'
  ];

  String validateAndSanitize(String response) {
    String sanitized = response;
    
    // Add disclaimers if missing
    bool hasDisclaimer = false;
    for (var disclaimer in _disclaimers) {
      if (sanitized.contains(disclaimer)) {
        hasDisclaimer = true;
        break;
      }
    }
    
    if (!hasDisclaimer) {
      sanitized += '\n\n⚠️ ' + _disclaimers.join('\n⚠️ ');
    }

    // Check critical terms
    for (var term in _criticalTerms) {
      if (sanitized.toLowerCase().contains(term)) {
        sanitized = _addWarningForTerm(sanitized, term);
      }
    }

    return sanitized;
  }

  String _addWarningForTerm(String response, String term) {
    final warning = '\n\n⚠️ Medical disclaimer: The use of "$term" should be confirmed by a healthcare professional.';
    return response + warning;
  }
}