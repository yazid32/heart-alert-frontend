// lib/services/multilingual_service.dart
class MultilingualService {
  static const Map<String, Map<String, String>> _medicalTerms = {
    'en': {
      'heart_attack': 'Myocardial infarction',
      'stroke': 'Cerebrovascular accident',
      'angina': 'Chest pain due to ischemia',
      'cholesterol': 'Total cholesterol',
      'blood_pressure': 'Arterial blood pressure',
    },
    'fr': {
      'heart_attack': 'Infarctus du myocarde',
      'stroke': 'Accident vasculaire cérébral',
      'angina': 'Angine de poitrine',
      'cholesterol': 'Cholestérol total',
      'blood_pressure': 'Tension artérielle',
    },
    'ar': {
      'heart_attack': 'احتشاء عضلة القلب',
      'stroke': 'السكتة الدماغية',
      'angina': 'الذبحة الصدرية',
      'cholesterol': 'الكوليسترول الكلي',
      'blood_pressure': 'ضغط الدم الشرياني',
    }
  };

  String detectLanguage(String text) {
    // Basic language detection
    if (text.contains(RegExp(r'[أ-ي]'))) return 'ar';
    if (text.contains(RegExp(r'[éèêëàâôû]'))) return 'fr';
    return 'en';
  }

  String translateTerm(String term, String targetLang) {
    // Search for the term in all languages
    for (var entry in _medicalTerms.entries) {
      // entry.key is the language code (en, fr, ar)
      // entry.value is the Map<String, String> of terms for that language
      if (entry.value.containsKey(term)) {
        // Found the term, now translate to target language
        final translated = entry.value[targetLang];
        if (translated != null && translated.isNotEmpty) {
          return translated;
        }
        // If translation not found, return the original term
        return term;
      }
    }
    return term;
  }

  String getSystemPromptForLanguage(String lang) {
    switch (lang) {
      case 'fr':
        return '''
You are HeartBot, an AI clinical assistant specialized in cardiology.
You ALWAYS respond in French.
Use appropriate French medical terminology.
Remind doctors to rely on their clinical judgment.
''';
      case 'ar':
        return '''
You are HeartBot, an AI clinical assistant specialized in cardiology.
You ALWAYS respond in Arabic.
Use appropriate Arabic medical terminology.
Remind doctors to rely on their clinical judgment.
''';
      default:
        return '''
You are HeartBot, an AI clinical assistant specialized in cardiology.
You ALWAYS respond in English.
Use appropriate medical terminology.
Remind doctors to rely on their clinical judgment.
''';
    }
  }
}