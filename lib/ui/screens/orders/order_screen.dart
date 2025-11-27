import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/app_notifier.dart';
import '../../../core/models/order_item.dart';
import '../../../core/print_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/print_preview_dialog.dart';

class OrderScreen extends StatelessWidget {
  const OrderScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AppNotifier>();
    final state = notifier.state;
    final orders = state.orders;
    final exportButton = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.print),
          label: const Text('Export / Print'),
          onPressed: () => PrintPreviewDialog.show(
            context,
            state,
            PrintSection.orders,
          ),
        ),
      ),
    );

    if (orders.isEmpty) {
      return Column(
        children: [
          exportButton,
          Expanded(
            child: EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'No supplier orders',
              message:
                  'Track planned deliveries by creating orders from the Warehouse tab.',
              buttonLabel: 'Show tip',
              onButtonPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Open the Warehouse tab and add items to the order list.',
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        exportButton,
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final isDelivered = order.status == OrderStatus.delivered;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Padding(
                    padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: _statusColor(order.status),
                            child: const Icon(
                              Icons.shopping_cart,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              order.product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Chip(
                            label: Text(_orderStatusLabel(order.status)),
                            avatar: Icon(
                              _orderStatusIcon(order.status),
                              size: 16,
                            ),
                            backgroundColor:
                                _statusColor(order.status)
                                    .withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              color: _statusColor(order.status),
                              fontWeight: FontWeight.w600,
                            ),
                            shape: StadiumBorder(
                              side: BorderSide(
                                color: _statusColor(order.status)
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _StatusFlow(order: order, colorBuilder: _statusColor),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 90,
                            child: TextFormField(
                              key: ValueKey(
                                'order_qty_${order.product.id}_${order.quantity}',
                              ),
                              initialValue: order.quantity.toString(),
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              enabled: !isDelivered,
                              decoration: const InputDecoration(
                                labelText: 'Qty',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onFieldSubmitted: (value) {
                                if (isDelivered) return;
                                final parsed =
                                    int.tryParse(value.trim()) ?? order.quantity;
                                context
                                    .read<AppNotifier>()
                                    .changeOrderQty(order.product.id, parsed);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildNextAction(context, order),
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
        ),
      ],
    );
  }

  Widget _buildNextAction(BuildContext context, OrderItem order) {
    switch (order.status) {
      case OrderStatus.pending:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton.icon(
              onPressed: () {
                context
                    .read<AppNotifier>()
                    .changeOrderStatus(order.product.id, OrderStatus.confirmed);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Order for ${order.product.name} confirmed',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.verified),
              label: const Text('Confirm order'),
            ),
            const SizedBox(height: 4),
            const Text(
              'Use once supplier accepted the order.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        );
      case OrderStatus.confirmed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton.icon(
              onPressed: () {
                context.read<AppNotifier>().markOrderDelivered(
                      order.product.id,
                    );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Delivered: +${order.quantity} ${order.product.name} to warehouse',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.local_shipping),
              label: const Text('Mark delivered'),
            ),
            const SizedBox(height: 4),
            const Text(
              'Adds delivered units to warehouse stock.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        );
      case OrderStatus.delivered:
        return const SizedBox.shrink();
    }
  }

}

class _StatusFlow extends StatelessWidget {
  final OrderItem order;
  final Color Function(OrderStatus) colorBuilder;

  const _StatusFlow({
    required this.order,
    required this.colorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final statuses = OrderStatus.values;
    final currentIndex = order.status.index;
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < statuses.length; i++) ...[
              _StatusNode(
                status: statuses[i],
                reached: currentIndex >= i,
                colorBuilder: colorBuilder,
              ),
              if (i < statuses.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: currentIndex > i
                        ? colorBuilder(statuses[i])
                        : Colors.grey.shade300,
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: statuses
              .map(
                (s) => Expanded(
                  child: Text(
                    _orderStatusLabel(s),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          order.status == s ? FontWeight.w600 : FontWeight.w400,
                      color: order.status == s
                          ? colorBuilder(s)
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _StatusNode extends StatelessWidget {
  final OrderStatus status;
  final bool reached;
  final Color Function(OrderStatus) colorBuilder;

  const _StatusNode({
    required this.status,
    required this.reached,
    required this.colorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final color = reached ? colorBuilder(status) : Colors.grey.shade400;
    return CircleAvatar(
      radius: 14,
      backgroundColor:
          color.withValues(alpha: reached ? 0.2 : 0.1),
      child: Icon(
        _orderStatusIcon(status),
        color: color,
        size: 18,
      ),
    );
  }
}

String _orderStatusLabel(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return 'Pending';
    case OrderStatus.confirmed:
      return 'Confirmed';
    case OrderStatus.delivered:
      return 'Delivered';
  }
}

IconData _orderStatusIcon(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return Icons.schedule;
    case OrderStatus.confirmed:
      return Icons.verified;
    case OrderStatus.delivered:
      return Icons.inventory_2;
  }
}
