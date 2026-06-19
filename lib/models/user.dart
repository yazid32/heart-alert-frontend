// lib/models/user.dart
class User {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final String status;
  final String? profilePicture;
  final String? specialty;
  final String? hospital;
  final int? assignedTo; // For assistants - which doctor they work for
  final String? subscriptionPlan; // for hospital/pro plans
  final String? plan; // alternative field name

  User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.status,
    this.profilePicture,
    this.specialty,
    this.hospital,
    this.assignedTo,
    this.subscriptionPlan, // ADD THIS
    this.plan, // ADD THIS
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['doctor_id'] ?? 0,
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      role: json['role'] ?? 'pending',
      status: json['status'] ?? 'pending',
      profilePicture: json['profile_picture'],
      specialty: json['specialty'],
      hospital: json['hospital'],
      assignedTo: json['assigned_to'],
      subscriptionPlan: json['subscription_plan'] ?? json['plan'], // ADD THIS
      plan: json['plan'], // ADD THIS
    );
  }

  String get fullName => '${firstName} ${lastName}';
  bool get isDoctor => role == 'doctor';
  bool get isAssistant => role == 'assistant';
  bool get isAdmin => role == 'admin';
  bool get isApproved => status == 'approved';
  bool get canPredict => role == 'doctor' || role == 'admin';
  
  // ADD THIS helper method
  bool get isHospitalAdmin {
    final userPlan = subscriptionPlan ?? plan ?? 'freemium';
    final planLower = userPlan.toLowerCase();
    return planLower == 'hospital' || 
           planLower == 'hospital_pro' || 
           planLower == 'hospital_plan' ||
           planLower == 'enterprise';
  }
}