class Doctor {
  final int? id;
  final String email;
  final String firstName;
  final String lastName;
  final String licenseNumber;
  final String hospital;
  final String? token;
  String? password;  // Made optional and nullable

  Doctor({
    this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.licenseNumber,
    required this.hospital,
    this.token,
    this.password,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: json['doctor_id'],
      email: json['email'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      licenseNumber: json['license_number'] ?? '',
      hospital: json['hospital'] ?? '',
      token: json['access_token'],
    );
  }

  Map<String, dynamic> toSignupJson() {
    return {
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'license_number': licenseNumber,
      'hospital': hospital,
    };
  }
}