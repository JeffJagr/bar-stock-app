import '../security/password_utils.dart';

enum StaffRole { admin, owner, manager, worker }

/// Describes an individual staff account. For Firebase Auth integration we
/// treat [login] as the email/username used for authentication while [id]
/// aligns with the auth UID whenever available. Until Firebase Auth is fully
/// wired, IDs continue to be generated locally.
class StaffMember {
  final String id;
  final String login;
  String displayName;
  StaffRole role;
  String passwordHash;
  String salt;
  final DateTime createdAt;
  final String? companyId;

  StaffMember({
    required this.id,
    required this.login,
    required this.displayName,
    required this.role,
    required this.passwordHash,
    required this.salt,
    required this.createdAt,
    this.companyId,
  });

  factory StaffMember.create({
    required String login,
    required String displayName,
    required StaffRole role,
    required String password,
  }) {
    final salt = PasswordUtils.generateSalt();
    return StaffMember(
      id: 'staff_${DateTime.now().millisecondsSinceEpoch}',
      login: login.trim().toLowerCase(),
      displayName: displayName.trim(),
      role: role,
      salt: salt,
      passwordHash: PasswordUtils.hashPassword(password, salt),
      createdAt: DateTime.now(),
      companyId: null,
    );
  }

  StaffMember copy() {
    return StaffMember(
      id: id,
      login: login,
      displayName: displayName,
      role: role,
      passwordHash: passwordHash,
      salt: salt,
      createdAt: createdAt,
      companyId: companyId,
    );
  }

  bool verifyPassword(String password) {
    return PasswordUtils.verifyPassword(password, salt, passwordHash);
  }

  StaffMember withPassword(String password) {
    final salt = PasswordUtils.generateSalt();
    return StaffMember(
      id: id,
      login: login,
      displayName: displayName,
      role: role,
      salt: salt,
      passwordHash: PasswordUtils.hashPassword(password, salt),
      createdAt: createdAt,
      companyId: companyId,
    );
  }

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: json['id'] as String,
      login: json['login'] as String,
      displayName: json['displayName'] as String? ?? '',
      role: StaffRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => StaffRole.worker,
      ),
      passwordHash: json['passwordHash'] as String? ?? '',
      salt: json['salt'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      companyId: json['companyId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'login': login,
      'displayName': displayName,
      'role': role.name,
      'passwordHash': passwordHash,
      'salt': salt,
      'createdAt': createdAt.toIso8601String(),
      if (companyId != null) 'companyId': companyId,
    };
  }
}
