import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/app_logic.dart';
import '../../../core/app_notifier.dart';
import '../../../core/models/inventory_item.dart';

class LowScreen extends StatelessWidget {
  const LowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AppNotifier>();
    final lowItems = AppLogic.lowItems(notifier.state);

    if (lowItems.isEmpty) {
      return const Center(
        child: Text('All items are green - nothing is low.'),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: lowItems.length,
            itemBuilder: (context, index) {
              final item = lowItems[index];

              final max = item.maxQty;
              final approx = item.approxQty;
              final percent =
                  (max > 0) ? ((approx / max) * 100).clamp(0, 100) : 0.0;

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: _levelColor(item.level),
                            child: Icon(
                              item.product.isAlcohol
                                  ? Icons.local_bar
                                  : Icons.local_drink,
                              color: Colors.white,
                            ),
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
                                  'Bar: ~ ${approx.toStringAsFixed(1)} / $max '
                                  '(${percent.toStringAsFixed(0)}%)',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  'Warehouse: ${item.warehouseQty}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.playlist_add),
                            tooltip: 'Add to Restock',
                            onPressed: () =>
                                notifier.addToRestock(item.product.id),
                          ),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 60,
                            child: TextFormField(
                              initialValue: item.maxQty.toString(),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Max',
                                labelStyle: TextStyle(fontSize: 10),
                                isDense: true,
                              ),
                              onFieldSubmitted: (value) {
                                final parsed =
                                    int.tryParse(value) ?? item.maxQty;
                                notifier.changeMaxQty(
                                  item.product.id,
                                  parsed,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text(
                            'Level',
                            style: TextStyle(fontSize: 11),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Slider(
                              value: percent.toDouble(),
                              min: 0,
                              max: 100,
                              divisions: 20,
                              label: '${percent.toStringAsFixed(0)}%',
                              activeColor: _levelColor(item.level),
                              onChanged: (value) {
                                notifier.changeFillPercent(
                                  item.product.id,
                                  value,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () {
              final added = notifier.addAllLowItemsToRestock();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    added
                        ? 'All low items added to Restock'
                        : 'No low items to add',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.playlist_add),
            label: const Text('Send all to Restock'),
          ),
        ),
      ],
    );
  }

  Color _levelColor(Level level) {
    switch (level) {
      case Level.green:
        return Colors.green;
      case Level.yellow:
        return Colors.amber;
      case Level.red:
        return Colors.red;
    }
  }
}
