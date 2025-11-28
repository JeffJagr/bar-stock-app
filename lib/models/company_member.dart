import '../core/security/password_utils.dart';

/// Represents a member/staff entry under a company (multi-tenant).
/// PINs are stored hashed; never persist raw PIN values.
class CompanyMember {
  final String memberId;
  final String companyId;
  final String displayName;
  final String role; // owner, manager, staff
  final String pinHash;
  final String pinSalt;
  final bool disabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CompanyMember({
    required this.memberId,
    required this.companyId,
    required this.displayName,
    required this.role,
    required this.pinHash,
    required this.pinSalt,
    required this.createdAt,
    required this.updatedAt,
    this.disabled = false,
  });

  CompanyMember copyWith({
    String? memberId,
    String? companyId,
    String? displayName,
    String? role,
    String? pinHash,
    String? pinSalt,
    bool? disabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompanyMember(
      memberId: memberId ?? this.memberId,
      companyId: companyId ?? this.companyId,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      pinHash: pinHash ?? this.pinHash,
      pinSalt: pinSalt ?? this.pinSalt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      disabled: disabled ?? this.disabled,
    );
  }

  factory CompanyMember.fromJson(Map<String, dynamic> json) {
    return CompanyMember(
      memberId: json['memberId'] as String? ??
          json['id'] as String? ??
          '',
      companyId: json['companyId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      role: (json['role'] as String? ?? 'staff').toLowerCase(),
      pinHash: json['pinHash'] as String? ?? '',
      pinSalt: json['pinSalt'] as String? ?? '',
      disabled: json['disabled'] as bool? ?? false,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'memberId': memberId,
      'companyId': companyId,
      'displayName': displayName,
      'role': role,
      'pinHash': pinHash,
      'pinSalt': pinSalt,
      'disabled': disabled,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static CompanyMember create({
    required String companyId,
    required String displayName,
    required String role,
    required String pin,
    required String memberId,
  }) {
    final salt = PasswordUtils.generateSalt();
    final hash = PasswordUtils.hashPassword(pin, salt);
    final now = DateTime.now();
    return CompanyMember(
      memberId: memberId,
      companyId: companyId,
      displayName: displayName.trim(),
      role: role.toLowerCase(),
      pinHash: hash,
      pinSalt: salt,
      createdAt: now,
      updatedAt: now,
      disabled: false,
    );
  }

  bool verifyPin(String pin) {
    return PasswordUtils.verifyPassword(pin, pinSalt, pinHash);
  }
}

DateTime _parseDate(dynamic raw) {
  if (raw is DateTime) return raw;
  if (raw is String) {
    return DateTime.tryParse(raw) ?? DateTime.now();
  }
  if (raw is num) {
    return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
  }
  try {
    final result = raw?.toDate();
    if (result is DateTime) {
      return result;
    }
  } catch (_) {}
  return DateTime.now();
}
