import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/app_notifier.dart';
import '../../../core/models/restock_item.dart';
import '../../../core/print_service.dart';
import '../../widgets/print_preview_dialog.dart';

class RestockScreen extends StatefulWidget {
  const RestockScreen({super.key});

  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> {
  final Set<String> _selected = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _errorByProduct = {};
  final ScrollController _restockListController = ScrollController();

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _restockListController.dispose();
    super.dispose();
  }

  TextEditingController _controllerFor(String productId) {
    return _controllers.putIfAbsent(
      productId,
      () => TextEditingController(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AppNotifier>();
    final restock = notifier.state.restock;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;
        final exportButton = Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.print),
              label: const Text('Export / Print'),
              onPressed: () => PrintPreviewDialog.show(
                context,
                notifier.state,
                PrintSection.restock,
              ),
            ),
          ),
        );

        if (restock.isEmpty) {
          return Column(
            children: [
              exportButton,
              const Expanded(
                child: Center(
                  child:
                      Text('Restock list is empty. Add items from Bar or Low.'),
                ),
              ),
            ],
          );
        }

    // чистим выбранные, если каких-то товаров уже нет
    final currentIds = restock.map((r) => r.product.id).toSet();
    _selected.removeWhere((id) => !currentIds.contains(id));
    final staleIds = _controllers.keys
        .where((id) => !currentIds.contains(id))
        .toList();
    if (staleIds.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _cleanupForProducts(staleIds);
        });
      });
    }

        final listView = Scrollbar(
          controller: _restockListController,
          thumbVisibility: isWide,
          child: ListView.builder(
            controller: _restockListController,
            itemCount: restock.length,
            itemBuilder: (context, index) {
              final item = restock[index];
              final id = item.product.id;
              final isSelected = _selected.contains(id);
              final controller = _controllerFor(id);
              final errorText = _errorByProduct[id];

              final maxInt = item.approxNeed.ceil().clamp(0, 1000000);

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selected.add(id);
                                } else {
                                  _selected.remove(id);
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Bar: ${item.approxCurrent.toStringAsFixed(1)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  'Need for full refill: ${item.approxNeed.toStringAsFixed(1)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Units to add',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: false,
                                signed: false,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                hintText: 'Enter units',
                                isDense: true,
                                errorText: errorText,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () {
                              if (maxInt <= 0) {
                                setState(() {
                                  _errorByProduct[id] = 'Nothing to refill';
                                });
                                return;
                              }
                              setState(() {
                                controller.text = maxInt.toString();
                                _errorByProduct[id] = null;
                              });
                            },
                            child: const Text('Full refill'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );

        final selectionSummary = _buildSelectionSummary(restock);

        final actionButtons = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _selected
                      ..clear()
                      ..addAll(restock.map((r) => r.product.id));
                  });
                },
                icon: const Icon(Icons.select_all),
                label: const Text('Select all'),
              ),
              OutlinedButton.icon(
                onPressed: _selected.isEmpty
                    ? null
                    : () {
                        setState(() {
                          _selected.clear();
                        });
                      },
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear selection'),
              ),
              OutlinedButton.icon(
                onPressed: _selected.isEmpty
                    ? null
                    : () => _fillSuggestedSelection(context, restock),
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Fill suggested'),
              ),
              ElevatedButton(
                onPressed: () => _applySelected(context, notifier, restock),
                child: const Text('Apply selected'),
              ),
              FilledButton(
                onPressed: () => _applyAll(context, notifier, restock),
                child: const Text('Apply all'),
              ),
            ],
          ),
        );

        Widget controls = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            exportButton,
            selectionSummary,
            actionButtons,
          ],
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 380,
                child: SingleChildScrollView(
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
            controls,
            Expanded(child: listView),
          ],
        );
      },
    );
  }

  Widget _buildSelectionSummary(List<RestockItem> restock) {
    final selectedItems = restock
        .where((r) => _selected.contains(r.product.id))
        .toList();
    if (selectedItems.isEmpty) {
      return const SizedBox.shrink();
    }
    final totalNeed = selectedItems.fold<double>(
      0,
      (sum, item) => sum + item.approxNeed,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        color: Colors.blueGrey.shade50,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selected ${selectedItems.length} item${selectedItems.length == 1 ? '' : 's'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Suggested total refill: ${totalNeed.toStringAsFixed(1)} units',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                'Use "Fill suggested" to copy recommended units before applying.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blueGrey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _cleanupForProducts(Iterable<String> productIds) {
    for (final id in productIds) {
      _errorByProduct.remove(id);
      final controller = _controllers.remove(id);
      controller?.dispose();
      _selected.remove(id);
    }
  }

  void _fillSuggestedSelection(
    BuildContext context,
    List<RestockItem> restock,
  ) {
    final items = restock
        .where((r) => _selected.contains(r.product.id))
        .toList();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select items to autofill')),
      );
      return;
    }
    setState(() {
      for (final item in items) {
        final suggested = item.approxNeed.ceil().clamp(0, 1000000);
        _controllerFor(item.product.id).text = suggested.toString();
        _errorByProduct[item.product.id] = null;
      }
    });
  }

  double? _resolveAmount(RestockItem item) {
    final id = item.product.id;
    final controller = _controllerFor(id);
    final raw = controller.text.trim();
    if (raw.isEmpty) {
      _errorByProduct[id] = 'Enter units';
      return null;
    }

    final value = int.tryParse(raw);
    if (value == null) {
      _errorByProduct[id] = 'Digits only';
      return null;
    }
    if (value <= 0) {
      _errorByProduct[id] = 'Must be > 0';
      return null;
    }

    final maxInt = item.approxNeed.ceil().clamp(0, 1000000);
    final maxAllowed =
        item.approxNeed > 0 ? maxInt.toDouble() : double.infinity;
    if (value > maxAllowed) {
      _errorByProduct[id] = 'Max $maxInt';
      return null;
    }

    _errorByProduct[id] = null;
    return value.toDouble();
  }

  Map<String, double>? _collectAmounts(
    List<RestockItem> items,
    BuildContext context,
  ) {
    final amounts = <String, double>{};
    var hasError = false;

    for (final item in items) {
      final amount = _resolveAmount(item);
      if (amount == null) {
        hasError = true;
      } else {
        amounts[item.product.id] = amount;
      }
    }

    setState(() {});

    if (hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fix invalid restock amounts')),
      );
      return null;
    }
    if (amounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items selected')),
      );
      return null;
    }
    return amounts;
  }

  void _applySelected(
    BuildContext context,
    AppNotifier notifier,
    List<RestockItem> restock,
  ) {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item')),
      );
      return;
    }
    final items = restock
        .where((r) => _selected.contains(r.product.id))
        .toList();
    final amounts = _collectAmounts(items, context);
    if (amounts == null) return;
    _applyAmounts(context, notifier, amounts, 'selected');
    setState(() {
      _cleanupForProducts(amounts.keys);
    });
  }

  void _applyAll(
    BuildContext context,
    AppNotifier notifier,
    List<RestockItem> restock,
  ) {
    final items = restock;
    if (items.isEmpty) return;
    final amounts = _collectAmounts(items, context);
    if (amounts == null) return;
    _applyAmounts(context, notifier, amounts, 'all');
    setState(() {
      _cleanupForProducts(amounts.keys);
    });
  }

  void _applyAmounts(
    BuildContext context,
    AppNotifier notifier,
    Map<String, double> amounts,
    String label,
  ) {
    final applied = notifier.applyCustomRestock(amounts);
    if (!applied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No restock amounts provided')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Applied restock for ${amounts.length} $label item(s)',
        ),
      ),
    );
  }
}
