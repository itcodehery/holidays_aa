/// User roles supported by the leave management system.
enum Role {
  employee('employee', 'Employee'),
  manager('manager', 'Manager'),
  hr('hr', 'HR / Admin');

  final String dbValue;
  final String label;
  const Role(this.dbValue, this.label);

  static Role fromString(String value) {
    return Role.values.firstWhere(
      (r) => r.dbValue == value || r.name == value,
      orElse: () => Role.employee,
    );
  }
}

/// Authenticated user profile.
class AppUser {
  final String id;
  final String email;
  final String fullName;
  final Role role;
  final String? managerId;
  final String? managerName;

  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.managerId,
    this.managerName,
  });

  bool get isEmployee => role == Role.employee;
  bool get isManager => role == Role.manager;
  bool get isHr => role == Role.hr;
  bool get canApprove => isManager || isHr;

  AppUser copyWith({
    String? id,
    String? email,
    String? fullName,
    Role? role,
    String? managerId,
    String? managerName,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      managerId: managerId ?? this.managerId,
      managerName: managerName ?? this.managerName,
    );
  }

  factory AppUser.fromJson(
    Map<String, dynamic> json, {
    String email = '',
    String? managerName,
  }) {
    return AppUser(
      id: json['id'] as String,
      email: (json['email'] as String?) ?? email,
      fullName: json['full_name'] as String,
      role: Role.fromString(json['role'] as String),
      managerId: json['manager_id'] as String?,
      managerName: managerName ?? (json['manager_name'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'role': role.dbValue,
        'manager_id': managerId,
        'manager_name': managerName,
      };
}
