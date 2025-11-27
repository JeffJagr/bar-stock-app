import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_logic.dart';
import '../../../core/app_notifier.dart';
import '../../../core/models/inventory_item.dart';
import '../../../core/models/order_item.dart';
import '../../../core/print_service.dart';
import '../../widgets/print_preview_dialog.dart';

class BarScreen extends StatefulWidget {
  final bool canEdit;
  final VoidCallback? onRequireManager;

  const BarScreen({
    super.key,
    required this.canEdit,
    this.onRequireManager,
  });

  @override
  State<BarScreen> createState() => _BarScreenState();
}

class _BarScreenState extends State<BarScreen> {
  /// Локальное хранение порядка внутри каждой группы
  final Map<String, List<String>> _orderByGroup = {};
  final ScrollController _groupListController = ScrollController();

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;
        final listView = groupNames.isEmpty
            ? const Center(
                child: Text('No groups yet. Add your first group.'),
              )
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
                width: 360,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 8),
                  child: controls,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: listView),
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
      ],
    );
  }

  // ---------- ORDER / SORT HELPERS ----------

  List<InventoryItem> _sortedItemsForGroup(
    String groupName,
    List<InventoryItem> raw,
  ) {
    final stored = _orderByGroup[groupName];
    if (stored == null) return raw;

    final map = <String, InventoryItem>{
      for (final i in raw) i.product.id: i,
    };

    final result = <InventoryItem>[];
    for (final id in stored) {
      final item = map.remove(id);
      if (item != null) result.add(item);
    }
    // новые товары в конце
    result.addAll(map.values);
    return result;
  }

  void _updateOrder(String groupName, List<String> ids) {
    setState(() {
      _orderByGroup[groupName] = ids;
    });
  }

  // ---------- GROUP UI ----------

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

    return ExpansionTile(
      title: Row(
        children: [
          Expanded(
            child: Text(
              groupName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (showLowBadge)
            _LowBadge(
              count: lowCount,
            ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            tooltip: 'Rename group',
            onPressed: widget.canEdit
                ? () => _showRenameGroupDialog(context, notifier, groupName)
                : widget.onRequireManager,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: 'Delete group',
            onPressed: widget.canEdit
                ? () => _confirmDeleteGroup(context, notifier, groupName)
                : widget.onRequireManager,
          ),
        ],
      ),
      children: [
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              'No products in this group yet.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        // Reorderable внутри группы
        if (items.isNotEmpty)
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
                : (_, __) => widget.onRequireManager?.call(),
            children: [
              for (final item in items)
                _buildItemCard(
                  context,
                  item,
                  notifier,
                  key: ValueKey(item.product.id),
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

  // ---------- ITEM CARD ----------

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
    final approx = item.approxQty;
    final percent =
        (max > 0) ? ((approx / max) * 100).clamp(0.0, 100.0) : 0.0;
    final sliderValue = percent.isNaN ? 0.0 : percent.clamp(0.0, 100.0);
    final sliderColor = _sliderColor(sliderValue);

    final productOrders = state.orders
        .where((o) =>
            o.product.id == item.product.id &&
            o.status != OrderStatus.delivered)
        .toList();

    String? onOrderText;
    if (productOrders.isNotEmpty) {
      final pending = productOrders
          .where((o) => o.status == OrderStatus.pending)
          .fold<int>(0, (sum, o) => sum + o.quantity);
      final confirmed = productOrders
          .where((o) => o.status == OrderStatus.confirmed)
          .fold<int>(0, (sum, o) => sum + o.quantity);

      final parts = <String>[];
      if (pending > 0) parts.add('$pending pending');
      if (confirmed > 0) parts.add('$confirmed confirmed');
      onOrderText = parts.join(', ');
    }

    return Card(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding:
            const EdgeInsets.only(left: 10, right: 10, top: 8, bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + buttons
            Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 160, maxWidth: 240),
                  child: Text(
                    item.product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Add to restock',
                  icon: const Icon(Icons.playlist_add),
                  onPressed: () =>
                      notifier.addToRestock(item.product.id),
                ),
                IconButton(
                  tooltip: 'Add to orders',
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: () {
                    notifier.addToOrder(item.product.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Added to orders')),
                    );
                  },
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        if (widget.canEdit) {
                          _showEditItemDialog(context, notifier, item);
                        } else {
                          widget.onRequireManager?.call();
                        }
                        break;
                      case 'move':
                        if (widget.canEdit) {
                          _showMoveDialog(context, notifier, item);
                        } else {
                          widget.onRequireManager?.call();
                        }
                        break;
                      case 'delete':
                        if (widget.canEdit) {
                          _confirmDeleteItem(context, notifier, item);
                        } else {
                          widget.onRequireManager?.call();
                        }
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit item'),
                    ),
                    const PopupMenuItem(
                      value: 'move',
                      child: Text('Move to group'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
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
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (value) {
                      final parsed = int.tryParse(value) ?? item.maxQty;
                      notifier.changeMaxQty(item.product.id, parsed);
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
                    Text(
                      '${sliderValue.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
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
                          disabledActiveTrackColor:
                              Colors.grey.shade300,
                          disabledInactiveTrackColor:
                              Colors.grey.shade200,
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
                                  notifier.changeFillPercent(
                                    item.product.id,
                                    value,
                                  );
                                },
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
                color: isStorageLow ? Colors.orange.shade700 : null,
              ),
            ),
            if (onOrderText != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.local_shipping,
                      size: 14, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    'On order: $onOrderText',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _sliderColor(double percent) {
    if (percent >= 70) return Colors.green.shade600;
    if (percent >= 40) return Colors.amber.shade700;
    return Colors.red.shade600;
  }

  // ---------- DIALOGS ----------

  void _showAddGroupDialog(BuildContext context, AppNotifier notifier) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Group name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                notifier.addGroup(name);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showRenameGroupDialog(
    BuildContext context,
    AppNotifier notifier,
    String oldName,
  ) {
    final controller = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != oldName) {
                notifier.renameGroup(oldName, newName);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog(
    BuildContext context,
    AppNotifier notifier, {
    required String initialGroup,
  }) {
    final existingGroups = AppLogic.groupNames(notifier.state);
    const newGroupKey = '__new__';

    String? selectedGroup =
        existingGroups.isNotEmpty ? existingGroups.first : null;
    bool useNewGroup = existingGroups.isEmpty;
    final newGroupController =
        TextEditingController(text: useNewGroup ? initialGroup : '');

    final nameController = TextEditingController();
    final maxController = TextEditingController(text: '0');
    final warehouseController = TextEditingController(text: '0');
    bool isAlcohol = true;
    bool addToWarehouse = true; // “также добавить в warehouse”

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) => AlertDialog(
            title: const Text('Add product'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Group selector
                  DropdownButtonFormField<String>(
                    initialValue: useNewGroup ? newGroupKey : selectedGroup,
                    items: [
                      ...existingGroups.map(
                        (g) => DropdownMenuItem(
                          value: g,
                          child: Text(g),
                        ),
                      ),
                      const DropdownMenuItem(
                        value: newGroupKey,
                        child: Text('+ New group...'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Group',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setStateDialog(() {
                        if (value == newGroupKey) {
                          useNewGroup = true;
                        } else {
                          useNewGroup = false;
                          selectedGroup = value;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  if (useNewGroup)
                    TextField(
                      controller: newGroupController,
                      decoration: const InputDecoration(
                        labelText: 'New group name',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Product name',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: isAlcohol,
                        onChanged: (v) =>
                            setStateDialog(() => isAlcohol = v ?? true),
                      ),
                      const Text('Alcohol'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: maxController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max in bar',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: addToWarehouse,
                        onChanged: (v) {
                          setStateDialog(() {
                            addToWarehouse = v ?? true;
                            if (!addToWarehouse) {
                              warehouseController.text = '0';
                            }
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'Also create stock in warehouse',
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                  if (addToWarehouse)
                    TextField(
                      controller: warehouseController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Qty in warehouse',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final groupName = useNewGroup
                      ? newGroupController.text.trim()
                      : (selectedGroup ?? '');
                  final prodName = nameController.text.trim();
                  final maxQty =
                      int.tryParse(maxController.text.trim()) ?? 0;
                  int whQty =
                      int.tryParse(warehouseController.text.trim()) ?? 0;

                  if (!addToWarehouse) {
                    whQty = 0;
                  }

                  if (groupName.isNotEmpty && prodName.isNotEmpty) {
                    notifier.addProduct(
                      groupName: groupName,
                      name: prodName,
                      isAlcohol: isAlcohol,
                      maxQty: maxQty,
                      warehouseQty: whQty,
                    );
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditItemDialog(
    BuildContext context,
    AppNotifier notifier,
    InventoryItem item,
  ) {
    final nameController = TextEditingController(text: item.product.name);
    final maxController = TextEditingController(text: item.maxQty.toString());
    final whController =
        TextEditingController(text: item.warehouseQty.toString());
    bool isAlcohol = item.product.isAlcohol;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Edit item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: isAlcohol,
                      onChanged: (v) => setStateDialog(() {
                        isAlcohol = v ?? true;
                      }),
                    ),
                    const Text('Alcohol'),
                  ],
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: maxController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max in bar',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: whController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Warehouse qty',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final max =
                    int.tryParse(maxController.text.trim()) ?? item.maxQty;
                final wh = int.tryParse(whController.text.trim()) ??
                    item.warehouseQty;
                notifier.editProduct(
                  productId: item.product.id,
                  name: nameController.text.trim(),
                  isAlcohol: isAlcohol,
                  maxQty: max,
                  warehouseQty: wh,
                );
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoveDialog(
    BuildContext context,
    AppNotifier notifier,
    InventoryItem item,
  ) {
    final groups = AppLogic.groupNames(notifier.state);
    final controller = TextEditingController(text: item.groupName);
    String selected = item.groupName;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: groups.contains(item.groupName)
                  ? item.groupName
                  : (groups.isNotEmpty ? groups.first : null),
              items: groups
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              decoration: const InputDecoration(
                labelText: 'Existing groups',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) {
                if (value != null) {
                  selected = value;
                  controller.text = value;
                }
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Or new group',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final target = controller.text.trim().isNotEmpty
                  ? controller.text.trim()
                  : selected;
              if (target.isNotEmpty) {
                notifier.editProduct(
                  productId: item.product.id,
                  groupName: target,
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Move'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteItem(
    BuildContext context,
    AppNotifier notifier,
    InventoryItem item,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item'),
        content:
            Text('Are you sure you want to delete "${item.product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              notifier.deleteProduct(item.product.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Item deleted')),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGroup(
    BuildContext context,
    AppNotifier notifier,
    String groupName,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete group'),
        content: Text(
            'Delete group "$groupName" and all items inside? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              notifier.deleteGroup(groupName);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Group "$groupName" deleted')),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
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

