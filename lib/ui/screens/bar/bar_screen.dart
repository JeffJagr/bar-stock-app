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
  final Map<String, bool> _groupExpanded = {};
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _groupListController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AppNotifier>();
    final state = notifier.state;
    final groupNames = AppLogic.groupNames(state);

    final normalizedQuery = _query.trim().toLowerCase();
    final filteredGroups = groupNames.where((group) {
      if (normalizedQuery.isEmpty) return true;
      final matchesGroup = group.toLowerCase().contains(normalizedQuery);
      final matchesItem = state.inventory.any(
        (i) =>
            i.groupName == group &&
            i.product.name.toLowerCase().contains(normalizedQuery),
      );
      return matchesGroup || matchesItem;
    }).toList();
    // Note: detail pane removed; selectedItem no longer used.

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = false; // force single-column layout; detail pane removed
        final listView = filteredGroups.isEmpty
            ? _buildBarEmptyState(context, notifier)
            : Scrollbar(
                controller: _groupListController,
                thumbVisibility: isWide,
                child: ListView.builder(
                  controller: _groupListController,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: filteredGroups.length,
                  itemBuilder: (context, index) {
                    final groupName = filteredGroups[index];
                    final rawItems = AppLogic.itemsForGroup(state, groupName)
                        .where((i) => i.maxQty > 0)
                        .where((i) => normalizedQuery.isEmpty
                            ? true
                            : i.product.name
                                .toLowerCase()
                                .contains(normalizedQuery))
                        .toList();
                    if (rawItems.isEmpty && normalizedQuery.isNotEmpty) {
                      return const SizedBox.shrink();
                    }
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

        return Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 4),
              child: Column(
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 8),
                  controls,
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: listView),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        labelText: 'Search products',
        isDense: true,
        border: const OutlineInputBorder(),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _query = '';
                  });
                },
              ),
      ),
      onChanged: (value) {
        setState(() {
          _query = value;
        });
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
    final expanded = _groupExpanded[groupName] ?? true;
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
            InkWell(
              onTap: () {
                setState(() {
                  _groupExpanded[groupName] = !expanded;
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    groupName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
                    case 'delete':
                      _showDeleteGroupDialog(
                        context,
                        notifier,
                        groupName,
                      );
                      break;
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Rename group'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete group'),
                  ),
                ],
              ),
          ],
        ),
        if (expanded) ...[
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
    final sliderColor = _sliderColor(sliderValue);

    final productOrders = state.orders
        .where((o) =>
            o.product.id == item.product.id &&
            o.status != OrderStatus.delivered)
        .toList();
    final onOrderQty = productOrders.fold<int>(
      0,
      (sum, o) => sum + o.quantity,
    );

    return Card(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: name + badges
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: sliderColor,
                  child: Icon(
                    item.product.isAlcohol ? Icons.local_bar : Icons.local_drink,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        item.groupName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      if (onOrderQty > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'On order: $onOrderQty',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.blueGrey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (isBarLow)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.warning_amber,
                        color: Colors.orange.shade700, size: 18),
                  ),
                if (isStorageLow)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.warehouse,
                        color: Colors.red.shade700, size: 18),
                  ),
                if (productOrders.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.shopping_cart,
                        color: Colors.blue.shade700, size: 18),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // Row 2: slider + numeric + max editor
            Row(
              children: [
                Text(
                  '${sliderValue.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: sliderColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: sliderColor,
                      inactiveTrackColor: Colors.grey.shade200,
                      thumbColor: sliderColor,
                      trackHeight: 8,
                    ),
                    child: Slider(
                      value: sliderValue,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: max <= 0 ? null : '${sliderValue.toStringAsFixed(0)}%',
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
                SizedBox(
                  width: 64,
                  child: TextFormField(
                    initialValue: max.toString(),
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
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Order',
                  icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                  onPressed: () => _promptOrder(context, notifier, item),
                ),
                IconButton(
                  tooltip: 'Restock',
                  icon: const Icon(Icons.playlist_add_check, size: 20),
                  onPressed: () => _addToRestock(context, notifier, item),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Row 3: textual stats
            Row(
              children: [
                Text(
                  'Bar: ~${approx.toStringAsFixed(1)} / $max',
                  style: TextStyle(
                    fontSize: 11,
                    color: isBarLow ? Colors.orange.shade700 : null,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Warehouse: ${item.warehouseQty}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isStorageLow ? Colors.red.shade700 : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _sliderColor(double percent) {
    if (percent >= 95) return Colors.green;
    if (percent >= 75) return Colors.orange;
    return Colors.red;
  }

  void _promptOrder(
    BuildContext context,
    AppNotifier notifier,
    InventoryItem item,
  ) {
    final qtyController = TextEditingController(text: '1');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Order ${item.product.name}'),
        content: TextField(
          controller: qtyController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Quantity',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final qty = int.tryParse(qtyController.text.trim()) ?? 0;
              if (qty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a positive quantity')),
                );
                return;
              }
              notifier.changeOrderQty(item.product.id, qty);
              notifier.addToOrder(item.product.id);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added $qty x ${item.product.name} to orders'),
                ),
              );
            },
            child: const Text('Add to order'),
          ),
        ],
      ),
    );
  }

  void _addToRestock(
    BuildContext context,
    AppNotifier notifier,
    InventoryItem item,
  ) {
    notifier.addToRestock(item.product.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.product.name} added to Restock')),
    );
  }

  Future<String?> _pickGroup(
    BuildContext context,
    List<String> groups,
    String current,
  ) {
    final searchCtrl = TextEditingController();
    String? selected = current.isNotEmpty ? current : null;

    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            final query = searchCtrl.text.trim().toLowerCase();
            final filtered = groups
                .where((g) => query.isEmpty || g.toLowerCase().contains(query))
                .toList();
            return AlertDialog(
              title: const Text('Select group'),
              content: SizedBox(
                width: 360,
                height: 360,
                child: Column(
                  children: [
                    TextField(
                      controller: searchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Search groups',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No groups yet'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final name = filtered[index];
                                final isSelected = selected == name;
                                return ListTile(
                                  title: Text(name),
                                  trailing: isSelected
                                      ? const Icon(Icons.check, color: Colors.blue)
                                      : null,
                                  onTap: () {
                                    setStateDialog(() {
                                      selected = name;
                                    });
                                  },
                                  onLongPress: () {
                                    Navigator.of(ctx).pop(name);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: selected == null
                      ? null
                      : () => Navigator.of(ctx).pop(selected),
                  child: const Text('Select'),
                ),
              ],
            );
          },
        );
      },
    );
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

  void _showAddGroupDialog(BuildContext context, AppNotifier notifier) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Group name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              notifier.addGroup(name);
              Navigator.of(ctx).pop();
            },
            child: const Text('Add'),
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
    final groups = AppLogic.groupNames(notifier.state);
    final nameCtrl = TextEditingController();
    final groupCtrl = TextEditingController(text: initialGroup);
    final maxCtrl = TextEditingController(text: '10');
    final whCtrl = TextEditingController(text: '0');
    bool isAlcohol = true;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          return AlertDialog(
            title: const Text('Add product'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Product name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: groupCtrl,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Group',
                      hintText: groups.isEmpty
                          ? 'No groups yet - add one'
                          : 'Select group',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_drop_down),
                        onPressed: () async {
                          final selected = await _pickGroup(
                            context,
                            groups,
                            groupCtrl.text,
                          );
                          if (!mounted) return;
                          if (selected != null) {
                            groupCtrl.text = selected;
                            setStateDialog(() {});
                          }
                        },
                      ),
                    ),
                    onTap: () async {
                      final selected = await _pickGroup(
                        context,
                        groups,
                        groupCtrl.text,
                      );
                      if (!mounted) return;
                      if (selected != null) {
                        groupCtrl.text = selected;
                        setStateDialog(() {});
                      }
                    },
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        _showAddGroupDialog(context, notifier);
                        // Refresh groups after dialog closes
                        setStateDialog(() {
                          final refreshed = AppLogic.groupNames(notifier.state);
                          if (refreshed.isNotEmpty && groupCtrl.text.isEmpty) {
                            groupCtrl.text = refreshed.first;
                          }
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Create new group'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: maxCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Max in bar',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: whCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Warehouse qty',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Alcohol'),
                    value: isAlcohol,
                    onChanged: (val) {
                      setStateDialog(() => isAlcohol = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  final group = groupCtrl.text.trim().isEmpty
                      ? initialGroup
                      : groupCtrl.text.trim();
                  final max = int.tryParse(maxCtrl.text.trim()) ?? 0;
                  final wh = int.tryParse(whCtrl.text.trim()) ?? 0;
                  if (name.isEmpty || group.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Name and group are required')),
                    );
                    return;
                  }
                  notifier.addProduct(
                    groupName: group,
                    name: name,
                    isAlcohol: isAlcohol,
                    maxQty: max,
                    warehouseQty: wh,
                  );
                  Navigator.of(ctx).pop();
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }
  void _showRenameGroupDialog(
    BuildContext context,
    AppNotifier notifier,
    String groupName,
  ) {
    final controller = TextEditingController(text: groupName);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              notifier.renameGroup(groupName, newName);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  void _showDeleteGroupDialog(
    BuildContext context,
    AppNotifier notifier,
    String groupName,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete group'),
        content: Text(
          'Delete "$groupName" and its products? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              notifier.deleteGroup(groupName);
              Navigator.of(ctx).pop();
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
