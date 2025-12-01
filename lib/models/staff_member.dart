import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/security/password_utils.dart';

/// Represents a staff/manager/owner member tied to a company.
class CompanyStaffMember {
  final String staffId;
  final String companyId;
  final String displayName;
  final String role; // owner, manager, staff
  final String pinHash;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  const CompanyStaffMember({
    required this.staffId,
    required this.companyId,
    required this.displayName,
    required this.role,
    required this.pinHash,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
  });

  CompanyStaffMember copyWith({
    String? staffId,
    String? companyId,
    String? displayName,
    String? role,
    String? pinHash,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return CompanyStaffMember(
      staffId: staffId ?? this.staffId,
      companyId: companyId ?? this.companyId,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      pinHash: pinHash ?? this.pinHash,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  factory CompanyStaffMember.fromJson(Map<String, dynamic> json) {
    return CompanyStaffMember(
      staffId: json['staffId'] as String? ?? json['id'] as String? ?? '',
      companyId: json['companyId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      role: (json['role'] as String? ?? 'staff').toLowerCase(),
      pinHash: json['pinHash'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'staffId': staffId,
      'companyId': companyId,
      'displayName': displayName,
      'role': role,
      'pinHash': pinHash,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static CompanyStaffMember create({
    required String staffId,
    required String companyId,
    required String displayName,
    required String role,
    required String pin,
  }) {
    final hash = PasswordUtils.hashPassword(pin, companyId);
    final now = DateTime.now();
    return CompanyStaffMember(
      staffId: staffId,
      companyId: companyId,
      displayName: displayName.trim(),
      role: role.toLowerCase(),
      pinHash: hash,
      createdAt: now,
      updatedAt: now,
      isActive: true,
    );
  }

  bool verifyPin(String pin) {
    return PasswordUtils.verifyPassword(pin, companyId, pinHash);
  }
}

DateTime _parseDate(dynamic raw) {
  if (raw is DateTime) return raw;
  if (raw is Timestamp) return raw.toDate();
  if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
  if (raw is num) return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
  return DateTime.now();
}
