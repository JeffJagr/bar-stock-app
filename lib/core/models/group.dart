class Group {
  String name;
  final int sortIndex;
  final String? companyId;

  Group({
    required this.name,
    required this.sortIndex,
    this.companyId,
  });

  Group copy() {
    return Group(
      name: name,
      sortIndex: sortIndex,
      companyId: companyId,
    );
  }

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      name: json['name'] as String? ?? '',
      sortIndex: json['sortIndex'] as int? ?? 0,
      companyId: json['companyId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sortIndex': sortIndex,
      if (companyId != null) 'companyId': companyId,
    };
  }
}
