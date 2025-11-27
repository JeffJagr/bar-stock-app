enum HistoryKind {
  general,
  bar,
  restock,
  order,
  warehouse,
  auth,
}

enum HistoryActionType {
  general,
  create,
  update,
  delete,
  login,
  logout,
}

class HistoryEntry {
  final DateTime timestamp;
  final String action;
  final HistoryKind kind;
  final HistoryActionType actionType;
  final String actorId;
  final String actorName;
  final String? companyId;
  final Map<String, dynamic>? meta;

  HistoryEntry({
    required this.timestamp,
    required this.action,
    required this.kind,
    required this.actionType,
    required this.actorId,
    required this.actorName,
    this.companyId,
    this.meta,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      action: json['action'] as String? ?? '',
      kind: HistoryKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => HistoryKind.general,
      ),
      actionType: HistoryActionType.values.firstWhere(
        (k) => k.name == json['actionType'],
        orElse: () => HistoryActionType.general,
      ),
      actorId: json['actorId'] as String? ?? 'system',
      actorName: json['actorName'] as String? ?? 'System',
      companyId: json['companyId'] as String?,
      meta: (json['meta'] as Map<String, dynamic>?),
    );
  }

  HistoryEntry copy() {
    return HistoryEntry(
      timestamp: timestamp,
      action: action,
      kind: kind,
      actionType: actionType,
      actorId: actorId,
      actorName: actorName,
      companyId: companyId,
      meta: meta == null ? null : Map<String, dynamic>.from(meta!),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'action': action,
      'kind': kind.name,
      'actionType': actionType.name,
      'actorId': actorId,
      'actorName': actorName,
      if (companyId != null) 'companyId': companyId,
      'meta': meta,
    };
  }
}
