import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/app_logic.dart';
import '../../../core/app_notifier.dart';
import '../../../core/models/inventory_item.dart';
import '../../../core/models/order_item.dart';
import '../../../core/print_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/print_preview_dialog.dart';

class BarScreen extends StatefulWidget {
  final bool canEdit;
  final VoidCallback? onRequireManager;
  final int? lowCountBadge;

  const BarScreen({
    super.key,
    required this.canEdit,
    this.onRequireManager,
    this.lowCountBadge,
  });

  @override
  State<BarScreen> createState() => _BarScreenState();
}

class _BarScreenState extends State<BarScreen> {
  // Track group order and pending slider values.
  final Map<String, List<String>> _orderByGroup = {};
  final ScrollController _groupListController = ScrollController();
  final Map<String, double> _pendingPercents = {};
  String? _selectedProductId;

  @override
  void dispose() {
    _groupListController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AppNotifier>();
    final state = notifier.state;
    final groupNames = AppLogic.groupNames(state);
    InventoryItem? selectedItem;
    if (state.inventory.isNotEmpty) {
      selectedItem = state.inventory
          .firstWhere((i) => i.product.id == _selectedProductId, orElse: () => state.inventory.first);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;
        final listView = groupNames.isEmpty
            ? _buildBarEmptyState(context, notifier)
            : Scrollbar(
                controller: _groupListController,
                thumbVisibility: isWide,
                child: ListView.builder(
                  controller: _groupListController,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: groupNames.length,
                  itemBuilder: (context, index) {
                    final groupName = groupNames[index];
                    final rawItems = AppLogic.itemsForGroup(state, groupName)
                        .where((i) => i.maxQty > 0)
                        .toList();
                    return _buildGroup(
                      context,
                      groupName,
                      rawItems,
                      notifier,
                    );
                  },
                ),
              );

        Widget controls = _buildTopControls(
          context,
          notifier,
          groupNames,
          constraints.maxWidth,
        );

        if (isWide) {
          controls = Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: controls,
            ),
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 8),
                  child: controls,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: listView),
              const SizedBox(width: 16),
              SizedBox(
                width: 320,
                child: _buildDetailPane(selectedItem),
              ),
            ],
          );
        }

        return Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 4),
              child: controls,
            ),
            const Divider(height: 1),
            Expanded(child: listView),
          ],
        );
      },
    );
  }

  Widget _buildTopControls(
    BuildContext context,
    AppNotifier notifier,
    List<String> groupNames,
    double maxWidth,
  ) {
    final isCompact = maxWidth < 520;
    final initialGroup = groupNames.isNotEmpty ? groupNames.first : '';
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.start,
      children: [
        SizedBox(
          width: isCompact ? double.infinity : 220,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.playlist_add),
            label: const Text('Add group'),
            onPressed: widget.canEdit
                ? () => _showAddGroupDialog(context, notifier)
                : widget.onRequireManager,
          ),
        ),
        SizedBox(
          width: isCompact ? double.infinity : 220,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_box),
            label: const Text('Add product'),
            onPressed: widget.canEdit
                ? () => _showAddProductDialog(
                      context,
                      notifier,
                      initialGroup: initialGroup,
                    )
                : widget.onRequireManager,
          ),
        ),
        SizedBox(
          width: isCompact ? double.infinity : 200,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Export / Print'),
            onPressed: () => PrintPreviewDialog.show(
              context,
              notifier.state,
              PrintSection.bar,
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildGroup(
    BuildContext context,
    String groupName,
    List<InventoryItem> rawItems,
    AppNotifier notifier,
  ) {
    final items = _sortedItemsForGroup(groupName, rawItems);
    final lowCount = AppLogic.barLowCountForGroup(
      notifier.state,
      groupName,
    );
    final showLowBadge = lowCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              groupName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            if (showLowBadge) _LowBadge(count: lowCount),
            const Spacer(),
            if (widget.canEdit)
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _showRenameGroupDialog(
                        context,
                        notifier,
                        groupName,
                      );
                      break;
                    case 'move':
                      _showMoveGroupDialog(
                        context,
                        notifier,
                        groupName,
                      );
                      break;
                    case 'delete':
                      _showDeleteGroupDialog(
                        context,
                        notifier,
                        groupName,
                      );
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit group'),
                  ),
                  const PopupMenuItem(
                    value: 'move',
                    child: Text('Reorder groups'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete group'),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          onReorder: widget.canEdit
              ? (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final currentOrder = (_orderByGroup[groupName] ??
                        items.map((e) => e.product.id).toList());
                    final ids = List<String>.from(currentOrder);
                    final moved = ids.removeAt(oldIndex);
                    ids.insert(newIndex, moved);
                    _orderByGroup[groupName] = ids;
                  });
                }
              : _handleReadOnlyReorder,
          children: [
            for (final item in items)
              InkWell(
                onTap: () => setState(() => _selectedProductId = item.product.id),
                key: ValueKey(item.product.id),
                child: _buildItemCard(
                  context,
                  item,
                  notifier,
                ),
              ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.canEdit
                ? () => _showAddProductDialog(
                      context,
                      notifier,
                      initialGroup: groupName,
                    )
                : widget.onRequireManager,
            icon: const Icon(Icons.add),
            label: const Text('Add product to this group'),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  // ... rest of the original bar screen code remains unchanged ...

  void _handleReadOnlyReorder(int oldIndex, int newIndex) {
    widget.onRequireManager?.call();
  }

  List<InventoryItem> _sortedItemsForGroup(
    String groupName,
    List<InventoryItem> raw,
  ) {
    final stored = _orderByGroup[groupName];

    final map = <String, InventoryItem>{
      for (final i in raw) i.product.id: i,
    };

    final result = <InventoryItem>[];
    if (stored != null) {
      for (final id in stored) {
        final item = map.remove(id);
        if (item != null) result.add(item);
      }
    }
    result.addAll(map.values);
    return result;
  }

  Widget _buildItemCard(
    BuildContext context,
    InventoryItem item,
    AppNotifier notifier, {
    Key? key,
  }) {
    final state = notifier.state;
    final isBarLow = AppLogic.isBarLow(item);
    final isStorageLow = AppLogic.isLowStock(item);
    final max = item.maxQty;
    final committedPercent =
        (max > 0) ? ((item.approxQty / max) * 100).clamp(0.0, 100.0) : 0.0;
    final pending = _pendingPercents[item.product.id];
    final sliderValue = (pending ?? committedPercent).clamp(0.0, 100.0);
    final approx = max > 0 ? (sliderValue / 100 * max) : item.approxQty;
    final percent = sliderValue;
    final sliderColor = _sliderColor(sliderValue);

    final productOrders = state.orders
        .where((o) =>
            o.product.id == item.product.id &&
            o.status != OrderStatus.delivered)
        .toList();

    return Card(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: sliderColor,
                  child: Icon(
                    item.product.isAlcohol ? Icons.local_bar : Icons.local_drink,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isBarLow)
                  const Icon(Icons.warning_amber, color: Colors.orange),
              ],
            ),
            const SizedBox(height: 4),
            // Max qty editor
            Row(
              children: [
                const Text(
                  'Max in bar:',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 70,
                  child: TextFormField(
                    initialValue: item.maxQty.toString(),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed == null || parsed < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Enter a non-negative number'),
                          ),
                        );
                        return;
                      }
                      final clamped = parsed.clamp(0, 1000000);
                      notifier.changeMaxQty(item.product.id, clamped);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Slider
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Level',
                      style: TextStyle(fontSize: 12),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _showNumericLevelDialog(
                        context,
                        notifier,
                        item,
                        committedPercent,
                      ),
                      child: Text(
                        '${sliderValue.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey.shade700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '0%',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: sliderColor,
                          inactiveTrackColor: Colors.grey.shade200,
                          disabledActiveTrackColor: Colors.grey.shade300,
                          disabledInactiveTrackColor: Colors.grey.shade200,
                          thumbColor: sliderColor,
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 18,
                          ),
                          trackHeight: 8,
                        ),
                        child: Slider(
                          value: sliderValue,
                          min: 0,
                          max: 100,
                          divisions: 20,
                          label: max <= 0
                              ? null
                              : '${sliderValue.toStringAsFixed(0)}%',
                          onChanged: max <= 0
                              ? null
                              : (value) {
                                  setState(() {
                                    _pendingPercents[item.product.id] =
                                        value.clamp(0, 100);
                                  });
                                },
                          onChangeEnd: max <= 0
                              ? null
                              : (value) => _confirmLevelChange(
                                    context,
                                    notifier,
                                    item,
                                    value,
                                    committedPercent,
                                  ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '100%',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Text(
              'Bar: ~ ${approx.toStringAsFixed(1)} / $max '
              '(${percent.toStringAsFixed(0)}%)',
              style: TextStyle(
                fontSize: 11,
                color: isBarLow ? Colors.orange.shade700 : null,
              ),
            ),
            Text(
              'Warehouse: ${item.warehouseQty}',
              style: TextStyle(
                fontSize: 11,
                color: isStorageLow ? Colors.red.shade700 : null,
              ),
            ),
            if (productOrders.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Open orders: ${productOrders.length}',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.delivered:
        return Colors.green;
    }
  }

  Color _sliderColor(double percent) {
    if (percent >= 95) return Colors.green;
    if (percent >= 75) return Colors.orange;
    return Colors.red;
  }

  // Dialogs and helpers omitted (same as original)...

  Future<void> _confirmLevelChange(
    BuildContext context,
    AppNotifier notifier,
    InventoryItem item,
    double newPercent,
    double oldPercent,
  ) async {
    final clampedNew = newPercent.clamp(0.0, 100.0);
    final max = item.maxQty;
    final oldApprox = max > 0 ? (oldPercent / 100 * max) : item.approxQty;
    final newApprox = max > 0 ? (clampedNew / 100 * max) : item.approxQty;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm change'),
        content: Text(
          'Change bar level for ${item.product.name}\n'
          'from ${oldPercent.toStringAsFixed(0)}% (~${oldApprox.toStringAsFixed(1)}) '
          'to ${clampedNew.toStringAsFixed(0)}% (~${newApprox.toStringAsFixed(1)})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      notifier.commitBarLevelChange(item.product.id, clampedNew);
    }
    setState(() {
      _pendingPercents.remove(item.product.id);
    });
  }

  Future<void> _showNumericLevelDialog(
    BuildContext context,
    AppNotifier notifier,
    InventoryItem item,
    double currentPercent,
  ) async {
    final controller =
        TextEditingController(text: currentPercent.toStringAsFixed(0));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Set bar level for ${item.product.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Percent (0-100)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final parsed = double.tryParse(controller.text.trim());
      if (parsed == null || parsed < 0 || parsed > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a value between 0 and 100')),
        );
        return;
      }
      _pendingPercents[item.product.id] = parsed;
      await _confirmLevelChange(
        context,
        notifier,
        item,
        parsed,
        currentPercent,
      );
    }
  }

  Widget _buildDetailPane(InventoryItem? item) {
    if (item == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Select a product to view details'),
        ),
      );
    }
    final max = item.maxQty;
    final percent =
        max > 0 ? ((item.approxQty / max) * 100).clamp(0.0, 100.0) : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.product.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bar: ${item.approxQty.toStringAsFixed(1)} / $max (${percent.toStringAsFixed(0)}%)',
            ),
            Text('Warehouse: ${item.warehouseQty}'),
            const SizedBox(height: 8),
            Text('Status: ${item.level.name.toUpperCase()}'),
          ],
        ),
      ),
    );
  }

  Widget _buildBarEmptyState(BuildContext context, AppNotifier notifier) {
    return EmptyState(
      icon: Icons.local_bar,
      title: 'No products yet',
      message: 'Add groups and products to start tracking your bar.',
      buttonLabel: widget.canEdit ? 'Add product' : null,
      onButtonPressed: widget.canEdit
          ? () => _showAddProductDialog(context, notifier, initialGroup: '')
          : widget.onRequireManager,
    );
  }

  void _showAddGroupDialog(BuildContext context, AppNotifier notifier) {}
  void _showAddProductDialog(
    BuildContext context,
    AppNotifier notifier, {
    required String initialGroup,
  }) {}
  void _showRenameGroupDialog(
    BuildContext context,
    AppNotifier notifier,
    String groupName,
  ) {}
  void _showMoveGroupDialog(
    BuildContext context,
    AppNotifier notifier,
    String groupName,
  ) {}
  void _showDeleteGroupDialog(
    BuildContext context,
    AppNotifier notifier,
    String groupName,
  ) {}
}

class _LowBadge extends StatelessWidget {
  final int count;

  const _LowBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          color: Colors.orange.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
