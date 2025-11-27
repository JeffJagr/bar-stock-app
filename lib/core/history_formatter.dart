import 'models/history_entry.dart';

class HistoryMessage {
  final String title;
  final String? detail;

  const HistoryMessage({
    required this.title,
    this.detail,
  });
}

class HistoryFormatter {
  static HistoryMessage describe(HistoryEntry entry) {
    switch (entry.kind) {
      case HistoryKind.order:
        return _orderMessage(entry);
      case HistoryKind.restock:
        return _restockMessage(entry);
      case HistoryKind.bar:
        return _barMessage(entry);
      case HistoryKind.warehouse:
        return _warehouseMessage(entry);
      case HistoryKind.auth:
        return _authMessage(entry);
      case HistoryKind.general:
      default:
        return HistoryMessage(
          title: entry.action,
          detail: null,
        );
    }
  }

  static HistoryMessage _orderMessage(HistoryEntry entry) {
    final product =
        _stringMeta(entry, 'productName') ?? 'Order item';
    final quantity = _formatUnits(_doubleMeta(entry, 'quantity'));
    final status = entry.actionType.name.toUpperCase();
    return HistoryMessage(
      title: 'Order - $product',
      detail: quantity != null
          ? '$status - Qty $quantity'
          : status,
    );
  }

  static HistoryMessage _restockMessage(HistoryEntry entry) {
    final product =
        _stringMeta(entry, 'productName') ?? 'Restock';
    final restocked = _formatUnits(_doubleMeta(entry, 'restocked'));
    final current =
        _doubleMeta(entry, 'newValue') ??
            _doubleMeta(entry, 'approx');
    final detail = restocked != null
        ? 'Added $restocked units'
        : null;
    final summary = current != null
        ? '$detail (bar ~${_formatUnits(current)})'
        : detail;
    return HistoryMessage(
      title: 'Restock - $product',
      detail: summary,
    );
  }

  static HistoryMessage _barMessage(HistoryEntry entry) {
    final product =
        _stringMeta(entry, 'productName') ?? 'Bar update';
    final delta = _doubleMeta(entry, 'delta');
    String? detail;
    if (delta != null) {
      final formatted = _formatUnits(delta.abs());
      if (formatted != null) {
        detail = delta >= 0
            ? 'Added $formatted to bar'
            : 'Used $formatted from bar';
      }
    }
    detail ??= entry.actionType.name.toUpperCase();
    return HistoryMessage(
      title: 'Bar - $product',
      detail: detail,
    );
  }

  static HistoryMessage _warehouseMessage(HistoryEntry entry) {
    final product =
        _stringMeta(entry, 'productName') ?? 'Warehouse update';
    final quantity = _formatUnits(_doubleMeta(entry, 'quantity'));
    final detail = quantity != null
        ? '${entry.actionType.name.toUpperCase()} - Qty $quantity'
        : entry.actionType.name.toUpperCase();
    return HistoryMessage(
      title: 'Warehouse - $product',
      detail: detail,
    );
  }

  static HistoryMessage _authMessage(HistoryEntry entry) {
    final actor = entry.actorName;
    final action = entry.actionType.name.toUpperCase();
    return HistoryMessage(
      title: 'Account - $actor',
      detail: action,
    );
  }

  static String? _formatUnits(double? value) {
    if (value == null) return null;
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  static double? _doubleMeta(HistoryEntry entry, String key) {
    final raw = entry.meta?[key];
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString());
  }

  static String? _stringMeta(HistoryEntry entry, String key) {
    final raw = entry.meta?[key];
    if (raw == null) return null;
    return raw.toString();
  }
}

