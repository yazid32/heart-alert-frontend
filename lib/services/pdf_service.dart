import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

class PdfService {
  static Future<void> exportPrediction(Map<String, dynamic> prediction, {bool share = false}) async {
    final pdf = pw.Document();
    
    final patientName = prediction['patient_name'] != null && prediction['patient_name'].toString().isNotEmpty
        ? prediction['patient_name']
        : 'Patient ${prediction['id']}';
    
    final riskScore = (prediction['risk_score'] as double) * 100;
    final riskCategory = prediction['risk_category'];
    
    final riskColor = riskCategory == 'high' 
        ? PdfColors.red 
        : riskCategory == 'moderate' 
            ? PdfColors.orange 
            : PdfColors.green;
    
    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Heart Alert',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Heart Disease Risk Assessment Report',
                      style: const pw.TextStyle(fontSize: 16, color: PdfColors.grey),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Divider(),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Risk Score Circle
              pw.Center(
                child: pw.Container(
                  width: 150,
                  height: 150,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    border: pw.Border.all(color: riskColor, width: 3),
                  ),
                  child: pw.Center(
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          '${riskScore.toInt()}%',
                          style: pw.TextStyle(
                            fontSize: 36,
                            fontWeight: pw.FontWeight.bold,
                            color: riskColor,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: riskColor,
                            borderRadius: pw.BorderRadius.circular(20),
                          ),
                          child: pw.Text(
                            riskCategory.toUpperCase(),
                            style: const pw.TextStyle(color: PdfColors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 30),
              
              // Patient Information
              pw.Text(
                'Patient Information',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              _infoRow('Patient Name', patientName),
              _infoRow('Patient ID', '#${prediction['id']}'),
              _infoRow('Age', '${prediction['age']} years'),
              _infoRow('Gender', prediction['sex'] == 1 ? 'Male' : 'Female'),
              _infoRow('Date', _formatDate(prediction['created_at'])),
              pw.SizedBox(height: 20),
              
              // Clinical Parameters
              pw.Text(
                'Clinical Parameters',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              _infoRow('Chest Pain Type', _getCpType(prediction['cp'])),
              _infoRow('Resting Blood Pressure', '${prediction['trestbps']} mm Hg'),
              _infoRow('Serum Cholesterol', '${prediction['chol']} mg/dl'),
              _infoRow('Fasting Blood Sugar', prediction['fbs'] == 1 ? '>120 mg/dl' : '≤120 mg/dl'),
              _infoRow('Resting ECG', _getRestEcg(prediction['restecg'])),
              _infoRow('Max Heart Rate', '${prediction['thalach']} bpm'),
              _infoRow('Exercise Angina', prediction['exang'] == 1 ? 'Yes' : 'No'),
              _infoRow('ST Depression', prediction['oldpeak'].toString()),
              _infoRow('ST Slope', _getSlope(prediction['slope'])),
              pw.SizedBox(height: 20),
              
              // Recommendation
              pw.Text(
                'Clinical Recommendation',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                _getRecommendation(riskCategory),
                style: const pw.TextStyle(fontSize: 12, height: 1.5),
              ),
              pw.SizedBox(height: 30),
              
              // Footer
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text(
                'Generated by Heart Alert - Clinical decision support only',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
    
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/heart_alert_report_${prediction['id']}.pdf');
    await file.writeAsBytes(await pdf.save());
    
    if (share) {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Heart Disease Risk Assessment Report for $patientName',
      );
    } else {
      await OpenFile.open(file.path);
    }
  }
  
  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 130,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
  
  static String _formatDate(String dateTimeStr) {
    try {
      final date = DateTime.parse(dateTimeStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }
  
  static String _getCpType(int cp) {
    switch (cp) {
      case 0: return 'Typical Angina';
      case 1: return 'Atypical Angina';
      case 2: return 'Non-anginal Pain';
      case 3: return 'Asymptomatic';
      default: return 'Unknown';
    }
  }
  
  static String _getRestEcg(int restecg) {
    switch (restecg) {
      case 0: return 'Normal';
      case 1: return 'ST-T Abnormality';
      case 2: return 'LV Hypertrophy';
      default: return 'Unknown';
    }
  }
  
  static String _getSlope(int slope) {
    switch (slope) {
      case 0: return 'Upsloping';
      case 1: return 'Flat';
      case 2: return 'Downsloping';
      default: return 'Unknown';
    }
  }
  
  
  static String _getRecommendation(String riskCategory) {
    switch (riskCategory) {
      case 'high':
        return 'Immediate cardiology consultation recommended. Further diagnostic tests such as ECG, echocardiogram, or stress test may be necessary. Consider lifestyle modifications and medication as prescribed.';
      case 'moderate':
        return 'Monitor closely. Consider lifestyle modifications including healthy diet, regular exercise, and stress management. Schedule follow-up appointment within 3 months.';
      default:
        return 'Low risk profile. Continue healthy lifestyle and routine screenings. Annual check-up recommended.';
    }
  }
}