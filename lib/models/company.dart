import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a tenant/company/bar entity containing all scoped data.
class Company {
  final String companyId;
  final String name;
  final String ownerUserId;
  final DateTime createdAt;

  const Company({
    required this.companyId,
    required this.name,
    required this.ownerUserId,
    required this.createdAt,
  });

  Company copyWith({
    String? companyId,
    String? name,
    String? ownerUserId,
    DateTime? createdAt,
  }) {
    return Company(
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Company.fromJson(Map<String, dynamic> json) {
    final dynamic created = json['createdAt'];
    DateTime createdAt = DateTime.now();
    if (created is Timestamp) {
      createdAt = created.toDate();
    } else if (created is String) {
      createdAt = DateTime.tryParse(created) ?? DateTime.now();
    } else if (created is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(created);
    }
    return Company(
      companyId: json['companyId'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      ownerUserId: json['ownerUserId'] as String? ?? '',
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'companyId': companyId,
      'name': name,
      'ownerUserId': ownerUserId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
