class Group {
  String name;
  final int sortIndex;

  Group({
    required this.name,
    required this.sortIndex,
  });

  Group copy() {
    return Group(
      name: name,
      sortIndex: sortIndex,
    );
  }

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      name: json['name'] as String? ?? '',
      sortIndex: json['sortIndex'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sortIndex': sortIndex,
    };
  }
}
