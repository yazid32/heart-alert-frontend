// lib/services/medical_knowledge_base.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MedicalKnowledgeBase {
  static const String _localDbKey = 'medical_knowledge_cache';
  
  final Map<String, String> _knowledgeBase = {
    'st_depression': '''
ST depression on ECG indicates myocardial ischemia. 
It can be caused by:
- Coronary artery disease
- Left ventricular hypertrophy
- Digoxin effect
- Hypokalemia
Clinical significance depends on patient context and other ECG findings.
''',
    'chest_pain_types': '''
Chest pain types in cardiology:
1. Typical Angina (Type 0): Substernal chest pain with exertion
2. Atypical Angina (Type 1): Atypical features, less predictable
3. Non-anginal Pain (Type 2): Not cardiac-related
4. Asymptomatic (Type 3): No pain, silent ischemia
''',
    'cholesterol_guidelines': '''
Cholesterol Guidelines (ESC/EAS 2019):
- Total Cholesterol: < 190 mg/dL (5.0 mmol/L)
- LDL Cholesterol: < 116 mg/dL (3.0 mmol/L) for low risk
- LDL Cholesterol: < 100 mg/dL (2.6 mmol/L) for moderate risk
- LDL Cholesterol: < 70 mg/dL (1.8 mmol/L) for high risk
- LDL Cholesterol: < 55 mg/dL (1.4 mmol/L) for very high risk
''',
    'blood_pressure_classification': '''
Blood Pressure Classification (ESC/ESH 2018):
- Optimal: < 120/80 mmHg
- Normal: 120-129/80-84 mmHg
- High Normal: 130-139/85-89 mmHg
- Grade 1 Hypertension: 140-159/90-99 mmHg
- Grade 2 Hypertension: 160-179/100-109 mmHg
- Grade 3 Hypertension: ≥ 180/110 mmHg
''',
  };

  String? searchKnowledge(String query) {
    final lowercaseQuery = query.toLowerCase();
    
    // Exact match search
    for (var entry in _knowledgeBase.entries) {
      if (lowercaseQuery.contains(entry.key) || 
          entry.key.contains(lowercaseQuery)) {
        return entry.value;
      }
    }
    
    // Keyword search
    final keywords = lowercaseQuery.split(' ');
    for (var entry in _knowledgeBase.entries) {
      for (var keyword in keywords) {
        if (keyword.length > 3 && entry.key.contains(keyword)) {
          return entry.value;
        }
      }
    }
    
    // Content search
    for (var entry in _knowledgeBase.entries) {
      if (entry.value.toLowerCase().contains(lowercaseQuery)) {
        return entry.value;
      }
    }
    
    return null;
  }
}