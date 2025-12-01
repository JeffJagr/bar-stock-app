import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/app_logic.dart';
import '../../../core/app_notifier.dart';
import '../../../core/constants.dart';
import '../../../core/constants/stock_thresholds.dart';
import '../../../core/models/inventory_item.dart';
import '../../../core/models/order_item.dart' as oi;
import '../../../core/print_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/print_preview_dialog.dart';

class WarehouseScreen extends StatefulWidget {
  final bool canEdit;
  final VoidCallback onRequireManager;

  const WarehouseScreen({
    super.key,
    required this.canEdit,
    required this.onRequireManager,
  });

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  String _query = '';
  final Map<String, TextEditingController> _warehouseControllers = {};
  final Map<String, FocusNode> _warehouseFocusNodes = {};
  final ScrollController _groupListController = ScrollController();

  @override
  void dispose() {
    for (final controller in _warehouseControllers.values) {
      controller.dispose();
    }
    for (final node in _warehouseFocusNodes.values) {
      node.dispose();
    }
    _groupListController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AppNotifier>();
    final state = notifier.state;
    final allGroups = AppLogic.groupNames(state);
    _cleanupMissingWarehouseControllers(
      state.inventory.map((item) => item.product.id),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;
        final listView = allGroups.isEmpty
            ? _buildWarehouseEmptyState(context, notifier)
            : Scrollbar(
                controller: _groupListController,
                thumbVisibility: isWide,
                child: ListView.builder(
                  controller: _groupListController,
                  itemCount: allGroups.length,
                  itemBuilder: (context, index) {
                    final groupName = allGroups[index];
                    final items = AppLogic.itemsForGroup(state, groupName)
                        .where((item) {
                      if (_query.isEmpty) return true;
                      return item.product.name
                          .toLowerCase()
                          .contains(_query.toLowerCase());
                    }).toList();
                    if (items.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return _buildGroup(
                      context,
                      groupName,
                      items,
                      notifier,
                    );
                  },
                ),
              );

        Widget controls = _buildTopBar(context, constraints.maxWidth, notifier);

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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: controls,
            ),
            const Divider(height: 1),
            Expanded(child: listView),
          ],
        );
      },
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    double maxWidth,
    AppNotifier notifier,
  ) {
    final isCompact = maxWidth < 640;
    return Wrap(
      runSpacing: 8,
      spacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: isCompact ? double.infinity : 360,
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search in warehouse',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {
                _query = value;
              });
            },
          ),
        ),
        SizedBox(
          width: isCompact ? double.infinity : 200,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_box),
            label: const Text('Add product'),
            onPressed: widget.canEdit
                ? () => _showAddProductDialog(context, notifier)
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
              PrintSection.warehouse,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWarehouseEmptyState(
    BuildContext context,
    AppNotifier notifier,
  ) {
    final buttonLabel =
        widget.canEdit ? 'Add product' : 'Request manager';
    final onPressed = widget.canEdit
        ? () => _showAddProductDialog(context, notifier)
        : widget.onRequireManager;

    return EmptyState(
      icon: Icons.warehouse_outlined,
      title: 'Warehouse is empty',
      message:
          'Add your first product to track backroom stock and supplier orders.',
      buttonLabel: buttonLabel,
      onButtonPressed: onPressed,
    );
  }

  Widget _buildGroup(
    BuildContext context,
    String groupName,
    List<InventoryItem> items,
    AppNotifier notifier,
  ) {
    final warehouseLowCount = AppLogic.lowStockCountForGroup(
      notifier.state,
      groupName,
    );
    final barLowCount = AppLogic.barLowCountForGroup(
      notifier.state,
      groupName,
    );
    return ExpansionTile(
      title: Row(
        children: [
          Expanded(
            child: Text(
              groupName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: warehouseLowCount > 0 || barLowCount > 0
                    ? Colors.orange
                    : null,
              ),
            ),
          ),
          if (warehouseLowCount > 0)
            _StatusBadge(
              label: 'WH',
              count: warehouseLowCount,
              color: Colors.orange.shade700,
            ),
          if (barLowCount > 0)
            _StatusBadge(
              label: 'BAR',
              count: barLowCount,
              color: Colors.purple.shade700,
            ),
        ],
      ),
      children: [
        ...items.map((item) => _buildItemCard(context, item, notifier)),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildItemCard(
    BuildContext context,
    InventoryItem item,
    AppNotifier notifier,
  ) {
    final state = notifier.state;
    final productOrders = state.orders
        .where((o) =>
            o.product.id == item.product.id &&
            o.status != oi.OrderStatus.delivered)
        .toList();

    String? onOrderText;
    if (productOrders.isNotEmpty) {
      final pending = productOrders
          .where((o) => o.status == oi.OrderStatus.pending)
          .fold<int>(0, (sum, o) => sum + o.quantity);
      final confirmed = productOrders
          .where((o) => o.status == oi.OrderStatus.confirmed)
          .fold<int>(0, (sum, o) => sum + o.quantity);
      final parts = <String>[];
      if (pending > 0) parts.add('$pending pending');
      if (confirmed > 0) parts.add('$confirmed confirmed');
      onOrderText = parts.join(', ');
    }

    final max = item.maxQty;
    final approx = item.approxQty;
    final percentBar =
        (max > 0) ? ((approx / max) * 100).clamp(0.0, 100.0) : 0.0;
    final isLowStock = AppLogic.isLowStock(item);
    final isBarLow = AppLogic.isBarLow(item);
    final trackingAllowed = AppConstants.warehouseTrackingEnabled;
    final trackingOn = trackingAllowed && item.trackWarehouseLevel;

    Color whColor;
    if (!trackingOn) {
      whColor = Colors.grey;
    } else {
      final base = max > 0 ? max.toDouble() : 100.0;
      final ratio =
          base > 0 ? (item.warehouseQty / base).clamp(0.0, 1.0) : 0.0;
      if (ratio == 0 || ratio < 0.3) {
        whColor = Colors.red;
      } else if (ratio < 0.7) {
        whColor = Colors.amber;
      } else {
        whColor = Colors.green;
      }
    }

    final controller = _warehouseControllerFor(item);
    final focusNode = _warehouseFocusNodeFor(item.product.id);
    final latestValue = item.warehouseQty.toString();
    if (!focusNode.hasFocus && controller.text != latestValue) {
      controller.text = latestValue;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding:
            const EdgeInsets.only(left: 10, right: 10, top: 8, bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.product.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (trackingOn && isLowStock)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.warning_amber,
                      color: Colors.orange.shade700,
                      size: 18,
                    ),
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
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Bar: ~ ${approx.toStringAsFixed(1)} / $max '
              '(${percentBar.toStringAsFixed(0)}%)',
              style: TextStyle(
                fontSize: 11,
                color: trackingOn
                    ? (isBarLow ? Colors.orange.shade700 : null)
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Warehouse',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: whColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Decrease by 1',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => _bumpWarehouseQty(
                    notifier,
                    item,
                    -1,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _commitWarehouseQty(notifier, item),
                    onEditingComplete: () =>
                        _commitWarehouseQty(notifier, item),
                  ),
                ),
                IconButton(
                  tooltip: 'Increase by 1',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _bumpWarehouseQty(
                    notifier,
                    item,
                    1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (trackingAllowed)
              Row(
                children: [
                  Checkbox(
                    value: trackingOn,
                    onChanged: (v) {
                      notifier.toggleTrackWarehouse(
                        item.product.id,
                        v ?? true,
                      );
                      setState(() {});
                    },
                  ),
                  Expanded(
                    child: Text(
                      'Track low alerts '
                      '(below ${(StockThresholds.warehouseLow * 100).toStringAsFixed(0)}%)',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Warehouse tracking disabled in config',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
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

  void _showAddProductDialog(
    BuildContext context,
    AppNotifier notifier,
  ) {
    final existingGroups = AppLogic.groupNames(notifier.state);
    const newGroupKey = '__new__';

    String? selectedGroup =
        existingGroups.isNotEmpty ? existingGroups.first : null;
    bool useNewGroup = existingGroups.isEmpty;
    final newGroupController = TextEditingController(
      text: useNewGroup ? '' : '',
    );

    final nameController = TextEditingController();
    final maxController = TextEditingController(text: '0');
    final warehouseController = TextEditingController(text: '0');
    bool isAlcohol = true;
    bool addToBar = true;

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
                  Row(
                    children: [
                      Checkbox(
                        value: addToBar,
                        onChanged: (v) {
                          setStateDialog(() {
                            addToBar = v ?? true;
                            if (!addToBar) {
                              maxController.text = '0';
                            }
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'Also create bar settings',
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                  if (addToBar)
                    TextField(
                      controller: maxController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Max in bar',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: warehouseController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
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
                  final maxRaw = int.tryParse(maxController.text.trim());
                  final whRaw = int.tryParse(warehouseController.text.trim());
                  if (maxRaw == null || maxRaw < 0 || whRaw == null || whRaw < 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Enter non-negative numbers for quantities'),
                      ),
                    );
                    return;
                  }
                  int maxQty = maxRaw;
                  final whQty = whRaw.clamp(0, 1000000);

                  if (!addToBar) {
                    maxQty = 0;
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

  TextEditingController _warehouseControllerFor(InventoryItem item) {
    return _warehouseControllers.putIfAbsent(
      item.product.id,
      () => TextEditingController(text: item.warehouseQty.toString()),
    );
  }

  FocusNode _warehouseFocusNodeFor(String productId) {
    return _warehouseFocusNodes.putIfAbsent(
      productId,
      () => FocusNode(),
    );
  }

  void _cleanupMissingWarehouseControllers(Iterable<String> ids) {
    final active = ids.toSet();
    final toRemove =
        _warehouseControllers.keys.where((id) => !active.contains(id)).toList();
    for (final id in toRemove) {
      _warehouseControllers.remove(id)?.dispose();
      _warehouseFocusNodes.remove(id)?.dispose();
    }
  }

  void _commitWarehouseQty(AppNotifier notifier, InventoryItem item) {
    final controller = _warehouseControllerFor(item);
    final parsed = int.tryParse(controller.text.trim());
    if (parsed == null || parsed < 0) {
      controller.text = item.warehouseQty.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid non-negative quantity')),
      );
      return;
    }
    final clamped = parsed.clamp(0, 1000000);
    if (clamped != parsed) {
      controller.text = clamped.toString();
    }
    notifier.changeWarehouseQty(item.product.id, clamped);
  }

  void _bumpWarehouseQty(
    AppNotifier notifier,
    InventoryItem item,
    int delta,
  ) {
    if (delta == 0) return;
    final next = (item.warehouseQty + delta).clamp(0, 1000000).toInt();
    notifier.changeWarehouseQty(item.product.id, next);
    _warehouseControllerFor(item).text = next.toString();
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
